use std::borrow::Cow;
use std::fs;
use std::io::{self, Read};
use std::path::PathBuf;

use clap::{value_parser, Arg, Command};
use rnix::{SyntaxElement, SyntaxKind, SyntaxNode, WalkEvent};

type Error = Box<dyn std::error::Error>;

enum Value {
    Raw(String),
    Set(usize),
}

struct Entry {
    path: Vec<String>,
    value: Value,
    blank_before: bool,
    leading: Vec<String>,
    trailing: Vec<String>,
}

#[derive(Default)]
struct Set {
    depth: usize,
    multiline: bool,
    entries: Vec<Entry>,
}

#[derive(Default)]
struct TrieNode<'a> {
    name: &'a str,
    children: Vec<usize>,
    value: Option<&'a Value>,
    blank_before: bool,
    leading: Vec<&'a str>,
    trailing: Vec<&'a str>,
}

enum RenderFrame {
    Children { parent: usize, next: usize },
    Entry(usize),
    FinishEntry(usize),
}

fn main() {
    let result = || -> Result<(), Error> {
        let matches = Command::new("nix-tidy")
            .arg(
                Arg::new("max-collapse")
                    .long("max-collapse")
                    .default_value("6")
                    .value_parser(value_parser!(usize)),
            )
            .arg(
                Arg::new("paths")
                    .value_parser(value_parser!(PathBuf))
                    .num_args(0..),
            )
            .get_matches();
        let max_collapse = *matches
            .get_one::<usize>("max-collapse")
            .expect("defaulted by clap");
        let mut paths = matches
            .get_many::<PathBuf>("paths")
            .into_iter()
            .flatten()
            .cloned()
            .collect::<Vec<_>>();

        if max_collapse == 0 {
            return Err(io::Error::new(
                io::ErrorKind::InvalidInput,
                "--max-collapse must be greater than 0",
            )
            .into());
        }

        if paths.is_empty() {
            let mut source = String::new();
            io::stdin().read_to_string(&mut source)?;
            print!("{}", rewrite(&source, max_collapse)?);
            return Ok(());
        }

        while let Some(path) = paths.pop() {
            if path.is_dir() {
                for entry in fs::read_dir(path)? {
                    let path = entry?.path();
                    if path.is_dir() {
                        if !matches!(
                            path.file_name().and_then(|name| name.to_str()),
                            Some(".direnv" | ".git" | "target")
                        ) {
                            paths.push(path);
                        }
                    } else if path.extension().is_some_and(|ext| ext == "nix") {
                        paths.push(path);
                    }
                }
                continue;
            }

            let before = fs::read_to_string(&path)?;
            let after = rewrite(&before, max_collapse)?;
            if after != before {
                fs::write(path, after)?;
            }
        }

        Ok(())
    }();

    if let Err(error) = result {
        eprintln!("nix-tidy: {error}");
        std::process::exit(1);
    }
}

fn rewrite(source: &str, max_collapse: usize) -> Result<String, Error> {
    fn go(source: &str, max_collapse: usize) -> Result<String, Error> {
        let parsed = rnix::Root::parse(source);
        if let Some(error) = parsed.errors().first() {
            return Err(io::Error::new(io::ErrorKind::InvalidData, error.to_string()).into());
        }

        let mut out = String::with_capacity(source.len());
        let mut walk = parsed.syntax().preorder_with_tokens();

        while let Some(event) = walk.next() {
            let WalkEvent::Enter(element) = event else {
                continue;
            };

            match element {
                SyntaxElement::Token(token) => out.push_str(token.text()),
                SyntaxElement::Node(node) if node.kind() == SyntaxKind::NODE_ATTR_SET => {
                    if let Some(text) = render_attrset(&node, max_collapse) {
                        out.push_str(&text);
                        walk.skip_subtree();
                    }
                }
                SyntaxElement::Node(_) => {}
            }
        }

        Ok(out)
    }

    let mut current = Cow::Borrowed(source);
    let passes = source.bytes().filter(|byte| *byte == b'{').count() + 1;

    for _ in 0..passes {
        let next = go(current.as_ref(), max_collapse)?;
        if next == current.as_ref() {
            return Ok(next);
        }
        current = Cow::Owned(next);
    }

    Err(io::Error::other("rewrite did not converge").into())
}

fn render_attrset(root: &SyntaxNode, max_collapse: usize) -> Option<String> {
    let mut sets = vec![Set::default()];
    let mut pending = vec![(root.clone(), 0)];

    while let Some((node, set_id)) = pending.pop() {
        for child in node.children() {
            if child.kind() != SyntaxKind::NODE_ATTRPATH_VALUE {
                return None;
            }
        }

        let mut blank_before = false;
        let mut leading = Vec::new();
        let mut after_binding_newline = true;

        for element in node.children_with_tokens() {
            match element {
                SyntaxElement::Node(child) => {
                    let mut node_leading = Vec::new();
                    let mut node_trailing = Vec::new();
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
                                        node_trailing.push(token.text().to_string());
                                    } else {
                                        node_leading.push(token.text().to_string());
                                    }
                                }
                                SyntaxKind::TOKEN_WHITESPACE => {
                                    if token.text().contains('\n') {
                                        sets[set_id].multiline = true;
                                    }
                                }
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
                            multiline: false,
                            entries: Vec::new(),
                        });
                        pending.push((value, child_id));
                        Value::Set(child_id)
                    } else {
                        Value::Raw(value.text().to_string())
                    };

                    let mut entry_leading = std::mem::take(&mut leading);
                    entry_leading.extend(node_leading);
                    sets[set_id].entries.push(Entry {
                        path,
                        value,
                        blank_before,
                        leading: entry_leading,
                        trailing: node_trailing,
                    });
                    blank_before = false;
                    after_binding_newline = false;
                }
                SyntaxElement::Token(token) => match token.kind() {
                    SyntaxKind::TOKEN_WHITESPACE => {
                        let newlines = token.text().chars().filter(|ch| *ch == '\n').count();
                        if newlines > 0 {
                            sets[set_id].multiline = true;
                            if newlines > 1 && !sets[set_id].entries.is_empty() {
                                blank_before = true;
                            }
                            after_binding_newline = true;
                        }
                    }
                    SyntaxKind::TOKEN_COMMENT => {
                        if !after_binding_newline {
                            sets[set_id]
                                .entries
                                .last_mut()?
                                .trailing
                                .push(token.text().to_string());
                        } else {
                            leading.push(token.text().to_string());
                        }
                        after_binding_newline = true;
                    }
                    SyntaxKind::TOKEN_L_BRACE | SyntaxKind::TOKEN_R_BRACE => {}
                    SyntaxKind::TOKEN_REC => return None,
                    _ => return None,
                },
            }
        }

        if !leading.is_empty() {
            return None;
        }
    }

    let mut rendered = vec![String::new(); sets.len()];
    for set_id in (0..sets.len()).rev() {
        let mut nodes = vec![TrieNode::default()];

        if !insert_set(&mut nodes, 0, set_id, &sets, max_collapse) {
            return None;
        }

        let multiline = sets[set_id].multiline;
        rendered[set_id] = if nodes[0].children.is_empty() {
            "{ }".to_string()
        } else {
            let mut out = if multiline {
                "{\n".to_string()
            } else {
                "{ ".to_string()
            };
            let mut stack = vec![RenderFrame::Children { parent: 0, next: 0 }];

            while let Some(frame) = stack.pop() {
                match frame {
                    RenderFrame::Children { parent, next } => {
                        if next >= nodes[parent].children.len() {
                            continue;
                        }
                        if next > 0 {
                            let previous = nodes[parent].children[next - 1];
                            let current = nodes[parent].children[next];
                            if nodes[previous].trailing.is_empty() {
                                if nodes[current].blank_before {
                                    out.push_str("\n\n");
                                } else if multiline {
                                    out.push('\n');
                                } else {
                                    out.push(' ');
                                }
                            }
                        }

                        stack.push(RenderFrame::Children {
                            parent,
                            next: next + 1,
                        });
                        stack.push(RenderFrame::Entry(nodes[parent].children[next]));
                    }
                    RenderFrame::Entry(mut node_id) => {
                        let mut leading = nodes[node_id].leading.clone();
                        let mut path_len = 1;
                        let mut path = nodes[node_id].name.to_string();
                        while nodes[node_id].value.is_none()
                            && nodes[node_id].trailing.is_empty()
                            && nodes[node_id].children.len() == 1
                            && nodes[nodes[node_id].children[0]].trailing.is_empty()
                            && path_len < max_collapse
                        {
                            node_id = nodes[node_id].children[0];
                            leading.extend(&nodes[node_id].leading);
                            path_len += 1;
                            path.push('.');
                            path.push_str(nodes[node_id].name);
                        }

                        for comment in leading {
                            out.push_str(comment);
                            out.push('\n');
                        }
                        out.push_str(&path);
                        out.push_str(" = ");

                        if let Some(value) = &nodes[node_id].value {
                            match value {
                                Value::Raw(text) => out.push_str(
                                    &rewrite(text, max_collapse)
                                        .unwrap_or_else(|_| text.to_string()),
                                ),
                                Value::Set(child_id) => out.push_str(&rendered[*child_id]),
                            }
                            out.push(';');
                            for comment in &nodes[node_id].trailing {
                                out.push(' ');
                                out.push_str(comment);
                                out.push('\n');
                            }
                        } else {
                            out.push_str(if multiline { "{\n" } else { "{ " });
                            stack.push(RenderFrame::FinishEntry(node_id));
                            stack.push(RenderFrame::Children {
                                parent: node_id,
                                next: 0,
                            });
                        }
                    }
                    RenderFrame::FinishEntry(node_id) => {
                        out.push_str(if multiline { "\n};" } else { " };" });
                        for comment in &nodes[node_id].trailing {
                            out.push(' ');
                            out.push_str(comment);
                            out.push('\n');
                        }
                    }
                }
            }
            out.push_str(if multiline { "\n}" } else { " }" });

            out
        };
    }

    Some(rendered.into_iter().next().unwrap_or_default())
}

fn trie_child<'a>(nodes: &mut Vec<TrieNode<'a>>, node_id: usize, name: &'a str) -> Option<usize> {
    if nodes[node_id].value.is_some() {
        return None;
    }

    if let Some(child_id) = nodes[node_id]
        .children
        .iter()
        .copied()
        .find(|child_id| nodes[*child_id].name == name)
    {
        return Some(child_id);
    }

    let child_id = nodes.len();
    nodes.push(TrieNode {
        name,
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
) -> bool {
    for entry in &sets[set_id].entries {
        let mut value = &entry.value;
        let mut node_id = parent;
        let mut path_len = entry.path.len();

        for (index, segment) in entry.path.iter().enumerate() {
            if let Some(Value::Set(child_id)) = nodes[node_id].value {
                if !nodes[node_id].leading.is_empty() || !nodes[node_id].trailing.is_empty() {
                    return false;
                }
                nodes[node_id].value = None;
                if !insert_set(nodes, node_id, *child_id, sets, max_collapse) {
                    return false;
                }
            }
            let Some(child_id) = trie_child(nodes, node_id, segment) else {
                return false;
            };
            node_id = child_id;
            if index == 0 && entry.blank_before {
                nodes[node_id].blank_before = true;
            }
        }

        while let Value::Set(child_id) = value {
            if !entry.leading.is_empty()
                || !entry.trailing.is_empty()
                || sets[*child_id].entries.len() != 1
            {
                break;
            }

            let child = &sets[*child_id].entries[0];
            if !child.leading.is_empty()
                || !child.trailing.is_empty()
                || sets[set_id].depth == 0
                    && matches!(child.value, Value::Raw(_))
                    && path_len + child.path.len() <= max_collapse
            {
                break;
            }

            for segment in &child.path {
                if let Some(Value::Set(child_id)) = nodes[node_id].value {
                    if !nodes[node_id].leading.is_empty() || !nodes[node_id].trailing.is_empty() {
                        return false;
                    }
                    nodes[node_id].value = None;
                    if !insert_set(nodes, node_id, *child_id, sets, max_collapse) {
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
                if !nodes[node_id].leading.is_empty() || !nodes[node_id].trailing.is_empty() {
                    return false;
                }
                nodes[node_id].value = None;
                if !insert_set(nodes, node_id, *existing_id, sets, max_collapse) {
                    return false;
                }
            }
            if !nodes[node_id].children.is_empty() {
                if !insert_set(nodes, node_id, *child_id, sets, max_collapse) {
                    return false;
                }
                continue;
            }
        }

        if nodes[node_id].value.is_some() || !nodes[node_id].children.is_empty() {
            return false;
        }
        nodes[node_id].value = Some(value);
        nodes[node_id].leading = entry.leading.iter().map(String::as_str).collect();
        nodes[node_id].trailing = entry.trailing.iter().map(String::as_str).collect();
    }

    true
}

fn static_path(binding: &SyntaxNode) -> Option<Vec<String>> {
    let path = binding
        .children()
        .find(|child| child.kind() == SyntaxKind::NODE_ATTRPATH)?;
    let mut names = Vec::new();

    for node in path.children() {
        match node.kind() {
            SyntaxKind::NODE_IDENT | SyntaxKind::NODE_STRING | SyntaxKind::NODE_DYNAMIC => {
                names.push(node.text().to_string())
            }
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

#[cfg(test)]
mod tests {
    use super::*;

    macro_rules! test {
        ($name:ident, $input:expr, $expected:expr) => {
            test!($name, depth = 6, $input, $expected);
        };
        ($name:ident, depth = $depth:expr, $input:expr, $expected:expr) => {
            #[test]
            fn $name() {
                assert_eq!(rewrite($input, $depth).unwrap(), $expected);
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
        leaves_layout_formatting_to_the_pipeline,
        r#"{ a.b = 1; a.c = 2; }"#,
        r#"{ a = { b = 1; c = 2; }; }"#
    );

    test!(
        rewrites_attrsets_with_dynamic_siblings,
        "{ ${a} = 1; b = { c.d = 1; c.e = 2; }; }",
        "{ ${a} = 1; b.c = { d = 1; e = 2; }; }"
    );

    test!(
        preserves_trailing_comments_while_grouping,
        "{ a.b = 1; # keep\n  a.c = 2; }",
        "{\na = {\nb = 1; # keep\nc = 2;\n};\n}"
    );

    test!(
        preserves_leading_comments_while_grouping,
        "{ # keep\n  a.b = 1; a.c = 2; }",
        "{\na = {\n# keep\nb = 1;\nc = 2;\n};\n}"
    );

    test!(
        preserves_leading_comments_on_compressed_attrpath_suffixes,
        "{ root = {\n# keep\na.b = 1; a.c = 2; }; }",
        "{ root.a = {\n# keep\nb = 1;\nc = 2;\n}; }"
    );

    test!(
        groups_siblings_when_another_value_contains_comments,
        "{ a = {\n# keep\nb = 1;\n}; c.d = 1; c.e = 2; }",
        "{ a = {\n# keep\nb = 1;\n}; c = { d = 1; e = 2; }; }"
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
        preserves_comments_between_bindings,
        "{\n  a = 1;\n  # keep one\n  # keep two\n  b = 2;\n}",
        "{\na = 1;\n# keep one\n# keep two\nb = 2;\n}"
    );

    test!(
        preserves_blank_lines_between_entries,
        "{ a = 1;\n\n  b.c = 2;\n\n  d = 3; }",
        "{\na = 1;\n\nb.c = 2;\n\nd = 3;\n}"
    );

    test!(
        preserves_multiline_single_entry_attrsets,
        "{\n  a = {\n    b = 1;\n  };\n}",
        "{\na = {\nb = 1;\n};\n}"
    );

    #[test]
    fn leaves_rec_attrsets_alone() {
        let input = "{ a = rec { b.c = 1; b.d = 2; }; }";
        assert_eq!(rewrite(input, 6).unwrap(), input);
    }
}
