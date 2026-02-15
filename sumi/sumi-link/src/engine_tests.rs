use super::{ConflictPolicy, Engine};
use crate::manifest::Manifest;
use crate::snapshot::Snapshot;
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
        "gruvbox",
        &[(".config/app/a.conf", &src1), (".config/app/b.conf", &src2)],
    );

    let engine = Engine {
        conflict_policy: ConflictPolicy::Backup,
    };
    let manifest = Manifest::load(&manifest_path).expect("load manifest");
    let summary = engine
        .apply(manifest, &state, "gruvbox")
        .expect("apply manifest");

    assert_eq!(summary.created, 2);
    assert_eq!(summary.updated, 0);
    assert_eq!(summary.removed, 0);
    assert_eq!(summary.failed, 0);

    assert_points_to(&home.join(".config/app/a.conf"), &src1);
    assert_points_to(&home.join(".config/app/b.conf"), &src2);

    let snapshot =
        Snapshot::read(&state.join("snapshot.json"), "gruvbox".to_string()).expect("read snapshot");
    assert_eq!(snapshot.files.len(), 2);
}

#[test]
fn second_apply_unchanged_is_noop() {
    let td = tempdir().expect("create tempdir");
    let home = td.path().join("home");
    let state = td.path().join("state");
    let sources = td.path().join("sources");
    fs::create_dir_all(&home).expect("create home");
    fs::create_dir_all(&sources).expect("create sources");

    let src1 = write_file(&sources.join("a"), "one");
    let manifest_path = td.path().join("manifest.json");
    write_manifest(
        &manifest_path,
        &home,
        "gruvbox",
        &[(".config/app/a.conf", &src1)],
    );

    let engine = Engine {
        conflict_policy: ConflictPolicy::Backup,
    };
    let manifest = Manifest::load(&manifest_path).expect("load manifest");
    engine
        .apply(manifest, &state, "gruvbox")
        .expect("first apply manifest");

    let manifest = Manifest::load(&manifest_path).expect("load manifest again");
    let summary = engine
        .apply(manifest, &state, "gruvbox")
        .expect("second apply manifest");

    assert_eq!(summary.created, 0);
    assert_eq!(summary.updated, 0);
    assert_eq!(summary.removed, 0);
    assert_eq!(summary.failed, 0);
    assert_eq!(summary.unchanged, 1);
}

#[test]
fn update_changes_link_target() {
    let td = tempdir().expect("create tempdir");
    let home = td.path().join("home");
    let state = td.path().join("state");
    let sources = td.path().join("sources");
    fs::create_dir_all(&home).expect("create home");
    fs::create_dir_all(&sources).expect("create sources");

    let src1 = write_file(&sources.join("a"), "one");
    let src2 = write_file(&sources.join("b"), "two");

    let m1 = td.path().join("manifest1.json");
    write_manifest(&m1, &home, "gruvbox", &[(".config/app/a.conf", &src1)]);

    let m2 = td.path().join("manifest2.json");
    write_manifest(&m2, &home, "gruvbox", &[(".config/app/a.conf", &src2)]);

    let engine = Engine {
        conflict_policy: ConflictPolicy::Backup,
    };
    engine
        .apply(Manifest::load(&m1).expect("load m1"), &state, "gruvbox")
        .expect("first apply");
    let summary = engine
        .apply(Manifest::load(&m2).expect("load m2"), &state, "gruvbox")
        .expect("second apply");

    assert_eq!(summary.updated, 1);
    assert_eq!(summary.failed, 0);
    assert_points_to(&home.join(".config/app/a.conf"), &src2);
}

#[test]
fn removes_stale_entries_from_snapshot() {
    let td = tempdir().expect("create tempdir");
    let home = td.path().join("home");
    let state = td.path().join("state");
    let sources = td.path().join("sources");
    fs::create_dir_all(&home).expect("create home");
    fs::create_dir_all(&sources).expect("create sources");

    let src1 = write_file(&sources.join("a"), "one");
    let src2 = write_file(&sources.join("b"), "two");

    let m1 = td.path().join("manifest1.json");
    write_manifest(
        &m1,
        &home,
        "gruvbox",
        &[(".config/app/a.conf", &src1), (".config/app/b.conf", &src2)],
    );

    let m2 = td.path().join("manifest2.json");
    write_manifest(&m2, &home, "gruvbox", &[(".config/app/a.conf", &src1)]);

    let engine = Engine {
        conflict_policy: ConflictPolicy::Backup,
    };
    engine
        .apply(Manifest::load(&m1).expect("load m1"), &state, "gruvbox")
        .expect("first apply");
    let summary = engine
        .apply(Manifest::load(&m2).expect("load m2"), &state, "gruvbox")
        .expect("second apply");

    assert_eq!(summary.removed, 1);
    assert!(!home.join(".config/app/b.conf").exists());
}

#[test]
fn backup_policy_moves_conflicting_file() {
    let td = tempdir().expect("create tempdir");
    let home = td.path().join("home");
    let state = td.path().join("state");
    let sources = td.path().join("sources");
    fs::create_dir_all(home.join(".config/app")).expect("create home app dir");
    fs::create_dir_all(&sources).expect("create sources");

    let src = write_file(&sources.join("a"), "one");
    let target = home.join(".config/app/a.conf");
    fs::write(&target, "unmanaged").expect("write unmanaged conflict");

    let manifest_path = td.path().join("manifest.json");
    write_manifest(
        &manifest_path,
        &home,
        "gruvbox",
        &[(".config/app/a.conf", &src)],
    );

    let engine = Engine {
        conflict_policy: ConflictPolicy::Backup,
    };
    let summary = engine
        .apply(
            Manifest::load(&manifest_path).expect("load manifest"),
            &state,
            "gruvbox",
        )
        .expect("apply");

    assert_eq!(summary.created, 1);
    assert_eq!(summary.failed, 0);
    assert_points_to(&target, &src);

    let backups = list_backup_entries(home.join(".config/app"));
    assert_eq!(backups.len(), 1);
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
    write_manifest(
        &manifest_path,
        &home,
        "gruvbox",
        &[(".config/app/dir", &src)],
    );

    let engine = Engine {
        conflict_policy: ConflictPolicy::Replace,
    };
    let summary = engine
        .apply(
            Manifest::load(&manifest_path).expect("load manifest"),
            &state,
            "gruvbox",
        )
        .expect("apply");

    assert_eq!(summary.created, 1);
    assert_eq!(summary.failed, 0);
    assert_points_to(&target, &src);
    assert!(!target.join("keep.txt").exists());
}

#[test]
fn missing_source_is_hard_error() {
    let td = tempdir().expect("create tempdir");
    let home = td.path().join("home");
    let state = td.path().join("state");
    let sources = td.path().join("sources");
    fs::create_dir_all(&home).expect("create home");
    fs::create_dir_all(&sources).expect("create sources");

    let src = write_file(&sources.join("exists"), "ok");
    let missing = sources.join("missing");

    let manifest_path = td.path().join("manifest.json");
    write_manifest(
        &manifest_path,
        &home,
        "gruvbox",
        &[
            (".config/app/a.conf", &src),
            (".config/app/b.conf", &missing),
        ],
    );

    let engine = Engine {
        conflict_policy: ConflictPolicy::Backup,
    };
    let err = engine
        .apply(
            Manifest::load(&manifest_path).expect("load manifest"),
            &state,
            "gruvbox",
        )
        .expect_err("missing sources should fail before apply");

    assert!(err
        .to_string()
        .contains("manifest contains missing source paths"));
    assert!(!home.join(".config/app/a.conf").exists());
    assert!(!home.join(".config/app/b.conf").exists());
}

#[test]
fn missing_theme_is_error() {
    let td = tempdir().expect("create tempdir");
    let home = td.path().join("home");
    let state = td.path().join("state");
    let sources = td.path().join("sources");
    fs::create_dir_all(&home).expect("create home");
    fs::create_dir_all(&sources).expect("create sources");

    let src = write_file(&sources.join("a"), "one");
    let manifest_path = td.path().join("manifest.json");
    write_manifest(
        &manifest_path,
        &home,
        "gruvbox",
        &[(".config/app/a.conf", &src)],
    );

    let engine = Engine {
        conflict_policy: ConflictPolicy::Backup,
    };
    let err = engine
        .apply(
            Manifest::load(&manifest_path).expect("load manifest"),
            &state,
            "not-a-theme",
        )
        .expect_err("missing theme should error");

    let msg = err.to_string();
    assert!(msg.contains("theme 'not-a-theme' was not found in manifest"));
}

#[test]
fn duplicate_paths_in_theme_is_error() {
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
  "defaultTheme": "gruvbox",
  "themes": {{
    "gruvbox": {{
      "files": [
        {{"path": ".config/app/a.conf", "source": "{}"}},
        {{"path": ".config/app/a.conf", "source": "{}"}}
      ]
    }}
  }}
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
            "gruvbox",
        )
        .expect_err("duplicate paths should error");

    let msg = err.to_string();
    assert!(msg.contains("duplicate file path '.config/app/a.conf' in theme 'gruvbox'"));
}

fn write_file(path: &Path, content: &str) -> PathBuf {
    if let Some(parent) = path.parent() {
        fs::create_dir_all(parent).expect("create parent for source");
    }
    fs::write(path, content).expect("write source file");
    path.to_path_buf()
}

fn write_manifest(manifest_path: &Path, home: &Path, theme: &str, entries: &[(&str, &Path)]) {
    let files = entries
        .iter()
        .map(|(path, source)| {
            format!(
                "{{\"path\":\"{}\",\"source\":\"{}\"}}",
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
  "defaultTheme": "{}",
  "themes": {{
    "{}": {{
      "files": [{}]
    }}
  }}
}}"#,
        escape_json_path(home),
        escape_json_str(theme),
        escape_json_str(theme),
        files
    );

    fs::write(manifest_path, text).expect("write manifest");
}

fn assert_points_to(target: &Path, source: &Path) {
    let meta = fs::symlink_metadata(target).expect("target metadata");
    assert!(meta.file_type().is_symlink());

    let actual = fs::read_link(target).expect("read symlink target");
    assert_eq!(actual, source);
}

fn list_backup_entries(dir: PathBuf) -> Vec<PathBuf> {
    let mut out = Vec::new();
    for entry in fs::read_dir(dir).expect("read backup parent dir") {
        let entry = entry.expect("read dir entry");
        let p = entry.path();
        if p.to_string_lossy().contains(".sumi.bak.") {
            out.push(p);
        }
    }
    out
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
        theme: "gruvbox".to_string(),
        updated_at: "0".to_string(),
        files,
    }
    .write_atomic(&state.join("snapshot.json"))
    .expect("write seeded snapshot");

    let manifest_path = td.path().join("manifest.json");
    write_manifest(
        &manifest_path,
        &home,
        "gruvbox",
        &[(".config/app/a.conf", &src_new)],
    );

    let engine = Engine {
        conflict_policy: ConflictPolicy::Replace,
    };
    let summary = engine
        .apply(
            Manifest::load(&manifest_path).expect("load manifest"),
            &state,
            "gruvbox",
        )
        .expect("apply");

    assert_eq!(summary.updated, 1);
    assert_eq!(summary.failed, 0);
    assert_points_to(&target, &src_new);
}
