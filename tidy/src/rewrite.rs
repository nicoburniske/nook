use std::io;

use alejandra::config::Config;
use rnix::{SyntaxElement, SyntaxKind, SyntaxNode, WalkEvent};
use rowan::{GreenNode, GreenToken, NodeOrToken};

use crate::Error;

type GreenElement = NodeOrToken<GreenNode, GreenToken>;

enum Value {
    Raw(GreenNode),
    Set(usize),
}

struct Segment {
    key: String,
    green: GreenNode,
}

struct Entry {
    path: Vec<Segment>,
    value: Value,
    comments_before: Vec<String>,
    comments_after: Vec<String>,
}

#[derive(Default)]
struct Set {
    depth: usize,
    entries: Vec<Entry>,
}

#[derive(Default)]
struct TrieNode<'a> {
    segment: Option<&'a Segment>,
    children: Vec<usize>,
    value: Option<&'a Value>,
    comments_before: Vec<&'a str>,
    comments_after: Vec<&'a str>,
}

pub fn format(source: &str, config: Config) -> Result<String, Error> {
    let parsed = parse(source)?;
    Ok(format_tree(parsed.syntax(), config))
}

pub fn rewrite(source: &str, max_collapse: usize, config: Config) -> Result<String, Error> {
    let parsed = parse(source)?;
    let tree = rewrite_tree(parsed.syntax(), max_collapse)?;
    Ok(format_tree(tree, config))
}

fn format_tree(root: SyntaxNode, config: Config) -> String {
    alejandra::format::syntax("nix-tidy".to_string(), root, config)
}

fn rewrite_tree(mut root: SyntaxNode, max_collapse: usize) -> Result<SyntaxNode, Error> {
    let passes = root
        .preorder_with_tokens()
        .filter(|event| {
            matches!(
                event,
                WalkEvent::Enter(SyntaxElement::Token(token))
                    if token.kind() == SyntaxKind::TOKEN_L_BRACE
            )
        })
        .count()
        + 1;

    for _ in 0..passes {
        let Some(next) = transform_once(&root, max_collapse)? else {
            return Ok(root);
        };
        root = next;
    }

    Err(io::Error::other("rewrite did not converge").into())
}

fn parse(source: &str) -> Result<rnix::Parse<rnix::Root>, Error> {
    let parsed = rnix::Root::parse(source);
    if let Some(error) = parsed.errors().first() {
        return Err(io::Error::new(io::ErrorKind::InvalidData, error.to_string()).into());
    }

    Ok(parsed)
}

fn transform_once(root: &SyntaxNode, max_collapse: usize) -> Result<Option<SyntaxNode>, Error> {
    let mut walk = root.preorder_with_tokens();

    while let Some(event) = walk.next() {
        let WalkEvent::Enter(element) = event else {
            continue;
        };

        match element {
            SyntaxElement::Node(node) if node.kind() == SyntaxKind::NODE_ATTR_SET => {
                if let Some(replacement) = replacement_attrset_green(&node, max_collapse) {
                    return Ok(Some(SyntaxNode::new_root(node.replace_with(replacement))));
                }
            }
            SyntaxElement::Node(_) | SyntaxElement::Token(_) => {}
        }
    }

    Ok(None)
}

fn replacement_attrset_green(root: &SyntaxNode, max_collapse: usize) -> Option<GreenNode> {
    let mut sets = vec![Set::default()];
    let mut pending = vec![(root.clone(), 0)];

    while let Some((node, set_id)) = pending.pop() {
        for child in node.children() {
            if child.kind() != SyntaxKind::NODE_ATTRPATH_VALUE {
                return None;
            }
        }

        let mut comments_before = Vec::new();
        let mut after_binding_newline = true;

        for element in node.children_with_tokens() {
            match element {
                SyntaxElement::Node(child) => {
                    let mut node_comments_before = Vec::new();
                    let mut node_comments_after = Vec::new();
                    let mut seen_path = false;
                    let mut seen_value = false;
                    for element in child.children_with_tokens() {
                        match element {
                            SyntaxElement::Node(node) => {
                                if node.kind() == SyntaxKind::NODE_ATTRPATH {
                                    seen_path = true;
                                } else if seen_path {
                                    seen_value = true;
                                }
                            }
                            SyntaxElement::Token(token) => match token.kind() {
                                SyntaxKind::TOKEN_COMMENT => {
                                    if seen_value {
                                        node_comments_after.push(token.text().to_string());
                                    } else {
                                        node_comments_before.push(token.text().to_string());
                                    }
                                }
                                SyntaxKind::TOKEN_WHITESPACE => {}
                                _ => {}
                            },
                        }
                    }

                    let path = static_path(&child)?;
                    let value = value_node(&child)?;
                    let value = if value.kind() == SyntaxKind::NODE_ATTR_SET {
                        let child_id = sets.len();
                        sets.push(Set {
                            depth: sets[set_id].depth + 1,
                            entries: Vec::new(),
                        });
                        pending.push((value, child_id));
                        Value::Set(child_id)
                    } else {
                        Value::Raw(value.green().into_owned())
                    };

                    let mut entry_comments_before = std::mem::take(&mut comments_before);
                    entry_comments_before.extend(node_comments_before);
                    sets[set_id].entries.push(Entry {
                        path,
                        value,
                        comments_before: entry_comments_before,
                        comments_after: node_comments_after,
                    });
                    after_binding_newline = false;
                }
                SyntaxElement::Token(token) => match token.kind() {
                    SyntaxKind::TOKEN_WHITESPACE => {
                        if token.text().contains('\n') {
                            after_binding_newline = true;
                        }
                    }
                    SyntaxKind::TOKEN_COMMENT => {
                        if !after_binding_newline {
                            sets[set_id]
                                .entries
                                .last_mut()?
                                .comments_after
                                .push(token.text().to_string());
                        } else {
                            comments_before.push(token.text().to_string());
                        }
                        after_binding_newline = true;
                    }
                    SyntaxKind::TOKEN_L_BRACE | SyntaxKind::TOKEN_R_BRACE => {}
                    SyntaxKind::TOKEN_REC => return None,
                    _ => return None,
                },
            }
        }

        if !comments_before.is_empty() {
            return None;
        }
    }

    let mut rendered = vec![None; sets.len()];
    let mut changed = false;
    for set_id in (0..sets.len()).rev() {
        let mut nodes = vec![TrieNode::default()];

        if !insert_set(&mut nodes, 0, set_id, &sets, max_collapse, &mut changed) {
            return None;
        }

        let attrset = if nodes[0].children.is_empty() {
            empty_attrset_green()
        } else {
            let mut children = vec![token(SyntaxKind::TOKEN_L_BRACE, "{"), whitespace(" ")];
            changed |= build_children(&mut children, &nodes, 0, &rendered, max_collapse);
            children.push(whitespace(" "));
            children.push(token(SyntaxKind::TOKEN_R_BRACE, "}"));
            node(SyntaxKind::NODE_ATTR_SET, children)
        };
        rendered[set_id] = Some(attrset);
    }

    if changed {
        rendered.into_iter().next().flatten()
    } else {
        None
    }
}

fn build_children(
    out: &mut Vec<GreenElement>,
    nodes: &[TrieNode<'_>],
    parent: usize,
    rendered: &[Option<GreenNode>],
    max_collapse: usize,
) -> bool {
    let mut changed = false;
    for (next, child_id) in nodes[parent].children.iter().copied().enumerate() {
        if next > 0 {
            let previous = nodes[parent].children[next - 1];
            if nodes[previous].comments_after.is_empty() {
                out.push(whitespace(" "));
            }
        }

        changed |= build_entry(out, nodes, child_id, rendered, max_collapse);
    }
    changed
}

fn build_entry(
    out: &mut Vec<GreenElement>,
    nodes: &[TrieNode<'_>],
    mut node_id: usize,
    rendered: &[Option<GreenNode>],
    max_collapse: usize,
) -> bool {
    fn push_comments(out: &mut Vec<GreenElement>, comments: &[&str], prefix: &str) {
        for comment in comments {
            if !prefix.is_empty() {
                out.push(whitespace(prefix));
            }
            out.push(token(SyntaxKind::TOKEN_COMMENT, comment));
            out.push(whitespace("\n"));
        }
    }

    let mut path_len = 1;
    let mut path = vec![nodes[node_id].segment.expect("named trie node")];
    push_comments(out, &nodes[node_id].comments_before, "");

    while nodes[node_id].value.is_none()
        && nodes[node_id].comments_after.is_empty()
        && nodes[node_id].children.len() == 1
        && nodes[nodes[node_id].children[0]].comments_after.is_empty()
        && path_len < max_collapse
    {
        node_id = nodes[node_id].children[0];
        push_comments(out, &nodes[node_id].comments_before, "");
        path_len += 1;
        path.push(nodes[node_id].segment.expect("named trie node"));
    }

    let mut binding = vec![
        attrpath_green(&path).into(),
        whitespace(" "),
        token(SyntaxKind::TOKEN_ASSIGN, "="),
        whitespace(" "),
    ];

    let changed = if let Some(value) = &nodes[node_id].value {
        match value {
            Value::Raw(value) => binding.push(value.clone().into()),
            Value::Set(child_id) => binding.push(
                rendered[*child_id]
                    .clone()
                    .expect("child attrset rendered first")
                    .into(),
            ),
        }
        false
    } else {
        let mut children = vec![token(SyntaxKind::TOKEN_L_BRACE, "{"), whitespace(" ")];
        let changed = build_children(&mut children, nodes, node_id, rendered, max_collapse)
            || nodes[node_id].children.len() > 1;
        children.push(whitespace(" "));
        children.push(token(SyntaxKind::TOKEN_R_BRACE, "}"));
        binding.push(node(SyntaxKind::NODE_ATTR_SET, children).into());
        changed
    };

    binding.push(token(SyntaxKind::TOKEN_SEMICOLON, ";"));
    out.push(node(SyntaxKind::NODE_ATTRPATH_VALUE, binding).into());
    push_comments(out, &nodes[node_id].comments_after, " ");
    changed
}

fn trie_child<'a>(
    nodes: &mut Vec<TrieNode<'a>>,
    node_id: usize,
    segment: &'a Segment,
) -> Option<usize> {
    if nodes[node_id].value.is_some() {
        return None;
    }

    if let Some(child_id) = nodes[node_id].children.iter().copied().find(|child_id| {
        nodes[*child_id]
            .segment
            .is_some_and(|node| node.key == segment.key)
    }) {
        return Some(child_id);
    }

    let child_id = nodes.len();
    nodes.push(TrieNode {
        segment: Some(segment),
        ..Default::default()
    });
    nodes[node_id].children.push(child_id);
    Some(child_id)
}

fn insert_set<'a>(
    nodes: &mut Vec<TrieNode<'a>>,
    parent: usize,
    set_id: usize,
    sets: &'a [Set],
    max_collapse: usize,
    changed: &mut bool,
) -> bool {
    for entry in &sets[set_id].entries {
        *changed |= entry.path.len() > max_collapse;
        let mut value = &entry.value;
        let mut node_id = parent;
        let mut path_len = entry.path.len();

        for segment in &entry.path {
            if let Some(Value::Set(child_id)) = nodes[node_id].value {
                nodes[node_id].value = None;
                *changed = true;
                if !insert_set(nodes, node_id, *child_id, sets, max_collapse, changed) {
                    return false;
                }
            }
            let Some(child_id) = trie_child(nodes, node_id, segment) else {
                return false;
            };
            node_id = child_id;
        }

        while let Value::Set(child_id) = value {
            if !entry.comments_before.is_empty()
                || !entry.comments_after.is_empty()
                || sets[*child_id].entries.len() != 1
                || path_len >= max_collapse
            {
                break;
            }

            let child = &sets[*child_id].entries[0];
            if !child.comments_before.is_empty()
                || !child.comments_after.is_empty()
                || sets[set_id].depth == 0
                    && matches!(child.value, Value::Raw(_))
                    && path_len + child.path.len() <= max_collapse
            {
                break;
            }

            *changed = true;
            for segment in &child.path {
                if let Some(Value::Set(child_id)) = nodes[node_id].value {
                    nodes[node_id].value = None;
                    if !insert_set(nodes, node_id, *child_id, sets, max_collapse, changed) {
                        return false;
                    }
                }
                let Some(child_id) = trie_child(nodes, node_id, segment) else {
                    return false;
                };
                node_id = child_id;
            }
            path_len += child.path.len();
            value = &child.value;
        }

        if let Value::Set(child_id) = value {
            if let Some(Value::Set(existing_id)) = nodes[node_id].value {
                nodes[node_id].value = None;
                *changed = true;
                if !insert_set(nodes, node_id, *existing_id, sets, max_collapse, changed) {
                    return false;
                }
            }
            if !nodes[node_id].children.is_empty() {
                *changed = true;
                nodes[node_id]
                    .comments_before
                    .extend(entry.comments_before.iter().map(String::as_str));
                nodes[node_id]
                    .comments_after
                    .extend(entry.comments_after.iter().map(String::as_str));
                if !insert_set(nodes, node_id, *child_id, sets, max_collapse, changed) {
                    return false;
                }
                continue;
            }
        }

        if nodes[node_id].value.is_some() || !nodes[node_id].children.is_empty() {
            return false;
        }
        nodes[node_id].value = Some(value);
        nodes[node_id].comments_before = entry.comments_before.iter().map(String::as_str).collect();
        nodes[node_id].comments_after = entry.comments_after.iter().map(String::as_str).collect();
    }

    true
}

fn static_path(binding: &SyntaxNode) -> Option<Vec<Segment>> {
    let path = binding
        .children()
        .find(|child| child.kind() == SyntaxKind::NODE_ATTRPATH)?;
    let mut names = Vec::new();

    for node in path.children() {
        match node.kind() {
            SyntaxKind::NODE_IDENT | SyntaxKind::NODE_STRING | SyntaxKind::NODE_DYNAMIC => names
                .push(Segment {
                    key: node.text().to_string(),
                    green: node.green().into_owned(),
                }),
            _ => {}
        }
    }

    (!names.is_empty()).then_some(names)
}

fn value_node(binding: &SyntaxNode) -> Option<SyntaxNode> {
    let mut seen_path = false;
    for child in binding.children() {
        if child.kind() == SyntaxKind::NODE_ATTRPATH {
            seen_path = true;
        } else if seen_path {
            return Some(child);
        }
    }
    None
}

fn empty_attrset_green() -> GreenNode {
    node(
        SyntaxKind::NODE_ATTR_SET,
        [
            token(SyntaxKind::TOKEN_L_BRACE, "{"),
            whitespace(" "),
            token(SyntaxKind::TOKEN_R_BRACE, "}"),
        ],
    )
}

fn attrpath_green(path: &[&Segment]) -> GreenNode {
    let mut children = Vec::new();
    for (index, segment) in path.iter().enumerate() {
        if index > 0 {
            children.push(token(SyntaxKind::TOKEN_DOT, "."));
        }
        children.push(segment.green.clone().into());
    }
    node(SyntaxKind::NODE_ATTRPATH, children)
}

fn node<I>(kind: SyntaxKind, children: I) -> GreenNode
where
    I: IntoIterator<Item = GreenElement>,
    I::IntoIter: ExactSizeIterator,
{
    GreenNode::new(rowan::SyntaxKind(kind as u16), children)
}

fn token(kind: SyntaxKind, text: &str) -> GreenElement {
    GreenToken::new(rowan::SyntaxKind(kind as u16), text).into()
}

fn whitespace(text: &str) -> GreenElement {
    token(SyntaxKind::TOKEN_WHITESPACE, text)
}

#[cfg(test)]
mod tests {
    use super::*;

    fn compact(text: &str) -> String {
        text.chars().filter(|ch| !ch.is_whitespace()).collect()
    }

    macro_rules! test {
        ($name:ident, $input:expr, $expected:expr) => {
            test!($name, depth = 6, $input, $expected);
        };
        (exact, $name:ident, $input:expr, $expected:expr) => {
            test!(exact, $name, depth = 6, $input, $expected);
        };
        ($name:ident, depth = $depth:expr, $input:expr, $expected:expr) => {
            test!($name, depth = $depth, map = compact, $input, $expected);
        };
        (exact, $name:ident, depth = $depth:expr, $input:expr, $expected:expr) => {
            test!($name, depth = $depth, map = str::to_string, $input, $expected);
        };
        ($name:ident, depth = $depth:expr, map = $map:expr, $input:expr, $expected:expr) => {
            #[test]
            fn $name() {
                let tree = parse($input).unwrap().syntax();
                let actual = rewrite_tree(tree, $depth).unwrap().text().to_string();
                assert_eq!($map(&actual), $map($expected));
            }
        };
    }

    test!(
        packs_siblings_and_collapses_singletons,
        "{ a.b = 1; a.c = 2; x = { y = { z = 3; }; }; }",
        "{ a = { b = 1; c = 2; }; x.y = { z = 3; }; }"
    );

    test!(
        reaches_fixed_point_in_one_rewrite,
        "{ a = { b.c = 1; b.d = 2; }; }",
        "{ a.b = { c = 1; d = 2; }; }"
    );

    test!(
        caps_singleton_collapse_depth,
        depth = 3,
        "{ a = { b = { c = { d = { e = { f = 1; }; }; }; }; }; }",
        "{ a.b.c = { d.e.f = 1; }; }"
    );

    test!(
        chunks_long_paths_and_resets_inside_the_split,
        "{ a.b.c.d.e.f.g.h.i = []; a.b.c.d.e.f.g.h.j = []; }",
        "{ a.b.c.d.e.f = { g.h = { i = []; j = []; }; }; }"
    );

    test!(
        chunks_long_paths_through_singleton_attrsets,
        "{ a = { b.c.d.e.f.g = 1; }; }",
        "{ a.b.c.d.e.f = { g = 1; }; }"
    );

    test!(
        rewrites_attrsets_with_dynamic_siblings,
        "{ ${a} = 1; b = { c.d = 1; c.e = 2; }; }",
        "{ ${a} = 1; b.c = { d = 1; e = 2; }; }"
    );

    test!(
        preserves_trailing_comments_while_grouping,
        "{ a.b = 1; # keep\n  a.c = 2; }",
        "{ a = { b = 1; # keep\n c = 2; }; }"
    );

    test!(
        preserves_leading_comments_while_grouping,
        "{ # keep\n  a.b = 1; a.c = 2; }",
        "{ a = { # keep\n b = 1; c = 2; }; }"
    );

    test!(
        preserves_leading_comments_on_compressed_attrpath_suffixes,
        "{ root = { # keep\n a.b = 1; a.c = 2; }; }",
        "{ root.a = { # keep\n b = 1; c = 2; }; }"
    );

    test!(
        groups_siblings_when_another_value_contains_comments,
        "{ a = { # keep\n b = 1; }; c.d = 1; c.e = 2; }",
        "{ a = { # keep\n b = 1; }; c = { d = 1; e = 2; }; }"
    );

    test!(
        rewrites_attrsets_inside_raw_values,
        "{ a = {b, ...}: { c.d = 1; c.e = 2; }; }",
        "{ a = {b, ...}: { c = { d = 1; e = 2; }; }; }"
    );

    test!(
        merges_dotted_siblings_into_direct_attrset_values,
        "{ a.b.c = 1; a = { d.e = 2; }; }",
        "{ a = { b.c = 1; d.e = 2; }; }"
    );

    test!(
        merges_duplicate_direct_attrset_values,
        "{ a = { b = 1; }; a = { c = 2; }; }",
        "{ a = { b = 1; c = 2; }; }"
    );

    test!(
        groups_dynamic_attrpaths,
        "{ a.b.c = {}; a.${d}.e = []; }",
        "{ a = { b.c = { }; ${d}.e = []; }; }"
    );

    test!(
        exact,
        merges_dotted_sibling_into_commented_attrset,
        "{  # keep\n  a = {    b = 1;  };  a.c = 2;}",
        "{ # keep\na = { b = 1; c = 2; }; }"
    );

    test!(
        exact,
        preserves_nested_comment_when_merging_outer_dotted_sibling,
        "{\n  a.b.c = 1;\n\n  a = {\n    # keep\n    b = {\n      d = 2;\n    };\n  };\n}",
        "{ # keep\na.b = { c = 1; d = 2; }; }"
    );

    test!(
        leaves_rec_attrsets_alone,
        "{ a = rec { b.c = 1; b.d = 2; }; }",
        "{ a = rec { b.c = 1; b.d = 2; }; }"
    );
}
