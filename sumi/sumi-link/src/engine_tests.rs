use super::{ConflictPolicy, Engine};
use crate::manifest::Manifest;
use crate::snapshot::Snapshot;
use std::collections::HashMap;
use std::fs;
use std::os::unix::fs::symlink;
use std::path::{Path, PathBuf};
use tempfile::tempdir;

#[test]
fn first_apply_creates_links_and_snapshot() {
    let td = tempdir().expect("create tempdir");
    let home = td.path().join("home");
    let state = td.path().join("state");
    let sources = td.path().join("sources");
    fs::create_dir_all(&home).expect("create home");
    fs::create_dir_all(&sources).expect("create sources");

    let src1 = write_file(&sources.join("a"), "one");
    let src2 = write_file(&sources.join("b"), "two");
    let manifest_path = td.path().join("manifest.json");
    write_manifest(
        &manifest_path,
        &home,
        &[(".config/app/a.conf", &src1), (".config/app/b.conf", &src2)],
    );

    let engine = Engine {
        conflict_policy: ConflictPolicy::Backup,
    };
    let manifest = Manifest::load(&manifest_path).expect("load manifest");
    let summary = engine
        .apply(manifest, &state, &HashMap::new())
        .expect("apply manifest");

    assert_eq!(summary.created, 2);
    assert_eq!(summary.updated, 0);
    assert_eq!(summary.removed, 0);
    assert_eq!(summary.failed, 0);

    assert_points_to(&home.join(".config/app/a.conf"), &src1);
    assert_points_to(&home.join(".config/app/b.conf"), &src2);

    let snapshot = Snapshot::read(&state.join("snapshot.json"), btreemap_theme("gruvbox"))
        .expect("read snapshot");
    assert_eq!(snapshot.files.len(), 2);
    assert_eq!(
        snapshot.selection.get("theme").map(String::as_str),
        Some("gruvbox")
    );
}

#[test]
fn switch_with_set_changes_selected_rules() {
    let td = tempdir().expect("create tempdir");
    let home = td.path().join("home");
    let state = td.path().join("state");
    let sources = td.path().join("sources");
    fs::create_dir_all(&home).expect("create home");
    fs::create_dir_all(&sources).expect("create sources");

    let src_gruv = write_file(&sources.join("gruv"), "one");
    let src_modus = write_file(&sources.join("modus"), "two");

    let manifest_path = td.path().join("manifest.json");
    write_manifest_rules(
        &manifest_path,
        &home,
        ".config/app/a.conf",
        &[("gruvbox", &src_gruv), ("modus", &src_modus)],
    );

    let engine = Engine {
        conflict_policy: ConflictPolicy::Backup,
    };

    engine
        .apply(
            Manifest::load(&manifest_path).expect("load manifest"),
            &state,
            &HashMap::new(),
        )
        .expect("default apply");
    assert_points_to(&home.join(".config/app/a.conf"), &src_gruv);

    let mut set = HashMap::new();
    set.insert("theme".to_string(), "modus".to_string());
    let summary = engine
        .apply(
            Manifest::load(&manifest_path).expect("reload manifest"),
            &state,
            &set,
        )
        .expect("set apply");

    assert_eq!(summary.updated, 1);
    assert_points_to(&home.join(".config/app/a.conf"), &src_modus);
}

#[test]
fn missing_source_is_hard_error() {
    let td = tempdir().expect("create tempdir");
    let home = td.path().join("home");
    let state = td.path().join("state");
    let sources = td.path().join("sources");
    fs::create_dir_all(&home).expect("create home");
    fs::create_dir_all(&sources).expect("create sources");

    let missing = sources.join("missing");

    let manifest_path = td.path().join("manifest.json");
    write_manifest(&manifest_path, &home, &[(".config/app/a.conf", &missing)]);

    let engine = Engine {
        conflict_policy: ConflictPolicy::Backup,
    };
    let err = engine
        .apply(
            Manifest::load(&manifest_path).expect("load manifest"),
            &state,
            &HashMap::new(),
        )
        .expect_err("missing sources should fail before apply");

    assert!(err
        .to_string()
        .contains("manifest contains missing source paths"));
}

#[test]
fn unknown_facet_set_fails() {
    let td = tempdir().expect("create tempdir");
    let home = td.path().join("home");
    fs::create_dir_all(&home).expect("create home");

    let manifest_path = td.path().join("manifest.json");
    write_manifest(&manifest_path, &home, &[]);

    let engine = Engine {
        conflict_policy: ConflictPolicy::Backup,
    };
    let mut set = HashMap::new();
    set.insert("density".to_string(), "compact".to_string());
    let err = engine
        .apply(
            Manifest::load(&manifest_path).expect("load manifest"),
            &td.path().join("state"),
            &set,
        )
        .expect_err("unknown facet should fail");

    assert!(err.to_string().contains("unknown facet 'density'"));
}

#[test]
fn duplicate_paths_in_manifest_is_error() {
    let td = tempdir().expect("create tempdir");
    let home = td.path().join("home");
    let state = td.path().join("state");
    let sources = td.path().join("sources");
    fs::create_dir_all(&home).expect("create home");
    fs::create_dir_all(&sources).expect("create sources");

    let src1 = write_file(&sources.join("a"), "one");
    let src2 = write_file(&sources.join("b"), "two");
    let manifest_path = td.path().join("manifest.json");
    let text = format!(
        r#"{{
  "version": 1,
  "home": "{}",
  "facets": {{ "theme": {{ "default": "gruvbox", "variants": {{ "gruvbox": {{}} }} }} }},
  "defaultSelection": {{ "theme": "gruvbox" }},
  "files": [
    {{ "path": ".config/app/a.conf", "rules": [{{"source": "{}"}}] }},
    {{ "path": ".config/app/a.conf", "rules": [{{"source": "{}"}}] }}
  ]
}}"#,
        escape_json_path(&home),
        escape_json_path(&src1),
        escape_json_path(&src2)
    );
    fs::write(&manifest_path, text).expect("write manifest");

    let engine = Engine {
        conflict_policy: ConflictPolicy::Backup,
    };
    let err = engine
        .apply(
            Manifest::load(&manifest_path).expect("load manifest"),
            &state,
            &HashMap::new(),
        )
        .expect_err("duplicate paths should fail");

    assert!(err
        .to_string()
        .contains("duplicate managed file path '.config/app/a.conf'"));
}

#[test]
fn replace_policy_replaces_conflicting_directory() {
    let td = tempdir().expect("create tempdir");
    let home = td.path().join("home");
    let state = td.path().join("state");
    let sources = td.path().join("sources");
    fs::create_dir_all(home.join(".config/app/dir")).expect("create home dir conflict");
    fs::create_dir_all(&sources).expect("create sources");

    let src = write_file(&sources.join("a"), "one");
    let target = home.join(".config/app/dir");
    fs::write(target.join("keep.txt"), "content").expect("seed conflicting dir");

    let manifest_path = td.path().join("manifest.json");
    write_manifest(&manifest_path, &home, &[(".config/app/dir", &src)]);

    let engine = Engine {
        conflict_policy: ConflictPolicy::Replace,
    };
    let summary = engine
        .apply(
            Manifest::load(&manifest_path).expect("load manifest"),
            &state,
            &HashMap::new(),
        )
        .expect("apply");

    assert_eq!(summary.created, 1);
    assert_eq!(summary.failed, 0);
    assert_points_to(&target, &src);
    assert!(!target.join("keep.txt").exists());
}

fn btreemap_theme(theme: &str) -> std::collections::BTreeMap<String, String> {
    let mut selection = std::collections::BTreeMap::new();
    selection.insert("theme".to_string(), theme.to_string());
    selection
}

fn write_file(path: &Path, content: &str) -> PathBuf {
    if let Some(parent) = path.parent() {
        fs::create_dir_all(parent).expect("create parent for source");
    }
    fs::write(path, content).expect("write source file");
    path.to_path_buf()
}

fn write_manifest(manifest_path: &Path, home: &Path, entries: &[(&str, &Path)]) {
    let files = entries
        .iter()
        .map(|(path, source)| {
            format!(
                "{{\"path\":\"{}\",\"rules\":[{{\"source\":\"{}\"}}]}}",
                escape_json_str(path),
                escape_json_path(source)
            )
        })
        .collect::<Vec<_>>()
        .join(",");

    let text = format!(
        r#"{{
  "version": 1,
  "home": "{}",
  "facets": {{
    "theme": {{
      "default": "gruvbox",
      "variants": {{ "gruvbox": {{}}, "modus": {{}} }}
    }}
  }},
  "defaultSelection": {{ "theme": "gruvbox" }},
  "files": [{}]
}}"#,
        escape_json_path(home),
        files
    );

    fs::write(manifest_path, text).expect("write manifest");
}

fn write_manifest_rules(manifest_path: &Path, home: &Path, path: &str, by_theme: &[(&str, &Path)]) {
    let rules = by_theme
        .iter()
        .map(|(theme, source)| {
            format!(
                "{{\"when\":{{\"theme\":[\"{}\"]}},\"source\":\"{}\"}}",
                escape_json_str(theme),
                escape_json_path(source)
            )
        })
        .collect::<Vec<_>>()
        .join(",");

    let text = format!(
        r#"{{
  "version": 1,
  "home": "{}",
  "facets": {{
    "theme": {{
      "default": "gruvbox",
      "variants": {{ "gruvbox": {{}}, "modus": {{}} }}
    }}
  }},
  "defaultSelection": {{ "theme": "gruvbox" }},
  "files": [
    {{ "path": "{}", "rules": [ {} ] }}
  ]
}}"#,
        escape_json_path(home),
        escape_json_str(path),
        rules
    );
    fs::write(manifest_path, text).expect("write manifest");
}

fn assert_points_to(target: &Path, source: &Path) {
    let meta = fs::symlink_metadata(target).expect("target metadata");
    assert!(meta.file_type().is_symlink());

    let actual = fs::read_link(target).expect("read symlink target");
    assert_eq!(actual, source);
}

fn escape_json_path(path: &Path) -> String {
    escape_json_str(&path.to_string_lossy())
}

fn escape_json_str(input: &str) -> String {
    input
        .replace('\\', "\\\\")
        .replace('"', "\\\"")
        .replace('\n', "\\n")
        .replace('\r', "\\r")
        .replace('\t', "\\t")
}

#[test]
fn update_replaces_wrong_old_symlink_when_policy_replace() {
    let td = tempdir().expect("create tempdir");
    let home = td.path().join("home");
    let state = td.path().join("state");
    let sources = td.path().join("sources");
    fs::create_dir_all(&home).expect("create home");
    fs::create_dir_all(&sources).expect("create sources");

    let src_old = write_file(&sources.join("old"), "old");
    let src_wrong = write_file(&sources.join("wrong"), "wrong");
    let src_new = write_file(&sources.join("new"), "new");

    let target = home.join(".config/app/a.conf");
    if let Some(parent) = target.parent() {
        fs::create_dir_all(parent).expect("create target parent");
    }

    symlink(&src_wrong, &target).expect("seed wrong symlink");

    let mut files = std::collections::BTreeMap::new();
    files.insert(
        target.to_string_lossy().into_owned(),
        src_old.to_string_lossy().into_owned(),
    );
    Snapshot {
        version: 1,
        selection: btreemap_theme("gruvbox"),
        updated_at: "0".to_string(),
        files,
    }
    .write_atomic(&state.join("snapshot.json"))
    .expect("write seeded snapshot");

    let manifest_path = td.path().join("manifest.json");
    write_manifest(&manifest_path, &home, &[(".config/app/a.conf", &src_new)]);

    let engine = Engine {
        conflict_policy: ConflictPolicy::Replace,
    };
    let summary = engine
        .apply(
            Manifest::load(&manifest_path).expect("load manifest"),
            &state,
            &HashMap::new(),
        )
        .expect("apply");

    assert_eq!(summary.updated, 1);
    assert_eq!(summary.failed, 0);
    assert_points_to(&target, &src_new);
}

#[test]
fn update_of_managed_symlink_does_not_backup_in_backup_policy() {
    let td = tempdir().expect("create tempdir");
    let home = td.path().join("home");
    let state = td.path().join("state");
    let sources = td.path().join("sources");
    fs::create_dir_all(&home).expect("create home");
    fs::create_dir_all(&sources).expect("create sources");

    let src_old = write_file(&sources.join("old"), "old");
    let src_new = write_file(&sources.join("new"), "new");

    let target = home.join(".config/app/a.conf");
    if let Some(parent) = target.parent() {
        fs::create_dir_all(parent).expect("create target parent");
    }
    symlink(&src_old, &target).expect("seed old symlink");

    let mut files = std::collections::BTreeMap::new();
    files.insert(
        target.to_string_lossy().into_owned(),
        src_old.to_string_lossy().into_owned(),
    );
    Snapshot {
        version: 1,
        selection: btreemap_theme("gruvbox"),
        updated_at: "0".to_string(),
        files,
    }
    .write_atomic(&state.join("snapshot.json"))
    .expect("write seeded snapshot");

    let manifest_path = td.path().join("manifest.json");
    write_manifest(&manifest_path, &home, &[(".config/app/a.conf", &src_new)]);

    let engine = Engine {
        conflict_policy: ConflictPolicy::Backup,
    };
    let summary = engine
        .apply(
            Manifest::load(&manifest_path).expect("load manifest"),
            &state,
            &HashMap::new(),
        )
        .expect("apply");

    assert_eq!(summary.updated, 1);
    assert_eq!(summary.failed, 0);
    assert_points_to(&target, &src_new);
    assert_eq!(count_backup_siblings(&target), 0);
}

fn count_backup_siblings(target: &Path) -> usize {
    let Some(parent) = target.parent() else {
        return 0;
    };
    let needle = format!("{}.sumi.bak.", target.display());
    fs::read_dir(parent)
        .expect("read target parent")
        .filter_map(Result::ok)
        .map(|entry| entry.path())
        .filter(|path| path.to_string_lossy().starts_with(&needle))
        .count()
}
