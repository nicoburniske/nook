use super::{
    apply, get_selection, load_manifest, parse_selection_overrides, read_snapshot,
    write_json_atomic, write_selection, ConflictPolicy,
};
use crate::error::AppError;
use crate::model::{CurrentSelection, Snapshot};
use serde_json::json;
use std::collections::BTreeMap;
use std::fs;
use std::os::unix::fs::symlink;
use std::path::{Path, PathBuf};
use std::time::Duration;
use tempfile::tempdir;

#[test]
fn first_apply_creates_links_and_snapshot() {
    smol::block_on(async {
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

        let manifest = load_manifest(&manifest_path).await.expect("load manifest");
        let summary = apply(
            manifest,
            &home,
            &state,
            &BTreeMap::new(),
            ConflictPolicy::Backup,
        )
        .await
        .expect("apply manifest");

        assert_eq!(summary.created, 2);
        assert_eq!(summary.updated, 0);
        assert_eq!(summary.removed, 0);
        assert_eq!(summary.failed, 0);

        assert_points_to(&home.join(".config/app/a.conf"), &src1);
        assert_points_to(&home.join(".config/app/b.conf"), &src2);

        let snapshot = read_snapshot(&state.join("snapshot.json"), btreemap_theme("gruvbox"))
            .await
            .expect("read snapshot");
        assert_eq!(snapshot.files.len(), 2);
        assert_eq!(
            snapshot.selection.get("theme").map(String::as_str),
            Some("gruvbox")
        );
    });
}

#[test]
fn switch_with_set_changes_selected_rules() {
    smol::block_on(async {
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

        apply(
            load_manifest(&manifest_path).await.expect("load manifest"),
            &home,
            &state,
            &BTreeMap::new(),
            ConflictPolicy::Backup,
        )
        .await
        .expect("default apply");
        assert_points_to(&home.join(".config/app/a.conf"), &src_gruv);

        let mut set = BTreeMap::new();
        set.insert("theme".to_string(), "modus".to_string());
        let summary = apply(
            load_manifest(&manifest_path)
                .await
                .expect("reload manifest"),
            &home,
            &state,
            &set,
            ConflictPolicy::Backup,
        )
        .await
        .expect("set apply");

        assert_eq!(summary.updated, 1);
        assert_points_to(&home.join(".config/app/a.conf"), &src_modus);
    });
}

#[test]
fn missing_source_is_hard_error() {
    smol::block_on(async {
        let td = tempdir().expect("create tempdir");
        let home = td.path().join("home");
        let state = td.path().join("state");
        let sources = td.path().join("sources");
        fs::create_dir_all(&home).expect("create home");
        fs::create_dir_all(&sources).expect("create sources");

        let missing = sources.join("missing");

        let manifest_path = td.path().join("manifest.json");
        write_manifest(&manifest_path, &home, &[(".config/app/a.conf", &missing)]);

        let err = apply(
            load_manifest(&manifest_path).await.expect("load manifest"),
            &home,
            &state,
            &BTreeMap::new(),
            ConflictPolicy::Backup,
        )
        .await
        .expect_err("missing sources should fail before apply");

        assert!(err
            .to_string()
            .contains("manifest contains missing source paths"));
    });
}

#[test]
fn unknown_facet_set_fails() {
    smol::block_on(async {
        let td = tempdir().expect("create tempdir");
        let home = td.path().join("home");
        fs::create_dir_all(&home).expect("create home");

        let manifest_path = td.path().join("manifest.json");
        write_manifest(&manifest_path, &home, &[]);

        let mut set = BTreeMap::new();
        set.insert("density".to_string(), "compact".to_string());
        let err = apply(
            load_manifest(&manifest_path).await.expect("load manifest"),
            &home,
            &td.path().join("state"),
            &set,
            ConflictPolicy::Backup,
        )
        .await
        .expect_err("unknown facet should fail");

        assert!(err.to_string().contains("unknown facet 'density'"));
    });
}

#[test]
fn duplicate_paths_in_manifest_is_error() {
    smol::block_on(async {
        let td = tempdir().expect("create tempdir");
        let home = td.path().join("home");
        let state = td.path().join("state");
        let sources = td.path().join("sources");
        fs::create_dir_all(&home).expect("create home");
        fs::create_dir_all(&sources).expect("create sources");

        let src1 = write_file(&sources.join("a"), "one");
        let src2 = write_file(&sources.join("b"), "two");
        let manifest_path = td.path().join("manifest.json");
        let text = serde_json::to_string_pretty(&json!({
            "version": 1,
            "home": home.to_string_lossy(),
            "facets": {
                "theme": {
                    "default": "gruvbox",
                    "variants": { "gruvbox": {} }
                }
            },
            "defaultSelection": { "theme": "gruvbox" },
            "files": [
                {
                    "path": ".config/app/a.conf",
                    "rules": [{ "source": src1.to_string_lossy() }]
                },
                {
                    "path": ".config/app/a.conf",
                    "rules": [{ "source": src2.to_string_lossy() }]
                }
            ]
        }))
        .expect("serialize manifest");
        fs::write(&manifest_path, text).expect("write manifest");

        let err = apply(
            load_manifest(&manifest_path).await.expect("load manifest"),
            &home,
            &state,
            &BTreeMap::new(),
            ConflictPolicy::Backup,
        )
        .await
        .expect_err("duplicate paths should fail");

        assert!(err
            .to_string()
            .contains("duplicate managed file path '.config/app/a.conf'"));
    });
}

#[test]
fn replace_policy_replaces_conflicting_directory() {
    smol::block_on(async {
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

        let summary = apply(
            load_manifest(&manifest_path).await.expect("load manifest"),
            &home,
            &state,
            &BTreeMap::new(),
            ConflictPolicy::Replace,
        )
        .await
        .expect("apply");

        assert_eq!(summary.created, 1);
        assert_eq!(summary.failed, 0);
        assert_points_to(&target, &src);
        assert!(!target.join("keep.txt").exists());
    });
}

#[test]
fn update_replaces_wrong_old_symlink_when_policy_replace() {
    smol::block_on(async {
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

        let mut files = BTreeMap::new();
        files.insert(
            target.to_string_lossy().into_owned(),
            src_old.to_string_lossy().into_owned(),
        );
        write_json_atomic(
            &Snapshot {
                version: 1,
                selection: btreemap_theme("gruvbox"),
                updated_at: "0".to_string(),
                files,
            },
            &state.join("snapshot.json"),
        )
        .await
        .expect("write seeded snapshot");

        let manifest_path = td.path().join("manifest.json");
        write_manifest(&manifest_path, &home, &[(".config/app/a.conf", &src_new)]);

        let summary = apply(
            load_manifest(&manifest_path).await.expect("load manifest"),
            &home,
            &state,
            &BTreeMap::new(),
            ConflictPolicy::Replace,
        )
        .await
        .expect("apply");

        assert_eq!(summary.updated, 1);
        assert_eq!(summary.failed, 0);
        assert_points_to(&target, &src_new);
    });
}

#[test]
fn update_of_managed_symlink_does_not_backup_in_backup_policy() {
    smol::block_on(async {
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

        let mut files = BTreeMap::new();
        files.insert(
            target.to_string_lossy().into_owned(),
            src_old.to_string_lossy().into_owned(),
        );
        write_json_atomic(
            &Snapshot {
                version: 1,
                selection: btreemap_theme("gruvbox"),
                updated_at: "0".to_string(),
                files,
            },
            &state.join("snapshot.json"),
        )
        .await
        .expect("write seeded snapshot");

        let manifest_path = td.path().join("manifest.json");
        write_manifest(&manifest_path, &home, &[(".config/app/a.conf", &src_new)]);

        let summary = apply(
            load_manifest(&manifest_path).await.expect("load manifest"),
            &home,
            &state,
            &BTreeMap::new(),
            ConflictPolicy::Backup,
        )
        .await
        .expect("apply");

        assert_eq!(summary.updated, 1);
        assert_eq!(summary.failed, 0);
        assert_points_to(&target, &src_new);
        assert_eq!(count_backup_siblings(&target), 0);
    });
}

#[test]
fn selection_round_trip_filters_invalid_variant() {
    smol::block_on(async {
        let td = tempdir().expect("create tempdir");
        let home = td.path().join("home");
        let state = td.path().join("state");
        fs::create_dir_all(&home).expect("create home");
        fs::create_dir_all(&state).expect("create state");

        let manifest_path = td.path().join("manifest.json");
        write_manifest(&manifest_path, &home, &[]);
        let manifest = load_manifest(&manifest_path).await.expect("load manifest");

        let mut invalid = BTreeMap::new();
        invalid.insert("theme".to_string(), "nonexistent".to_string());
        write_json_atomic(
            &CurrentSelection {
                selection: invalid,
                switched_at: "0".to_string(),
            },
            &state.join("current.json"),
        )
        .await
        .expect("write current");

        let selection = get_selection(&manifest, &state)
            .await
            .expect("read selection");
        assert_eq!(selection.get("theme").map(String::as_str), Some("gruvbox"));

        write_selection(&state, &selection)
            .await
            .expect("write selection");
        let reloaded = get_selection(&manifest, &state)
            .await
            .expect("reload selection");
        assert_eq!(reloaded.get("theme").map(String::as_str), Some("gruvbox"));
    });
}

#[test]
fn parse_selection_overrides_rejects_invalid_pairs() {
    let err = parse_selection_overrides(&["theme".to_string()]).expect_err("must fail");
    assert!(err.to_string().contains("expected facet=value"));
}

#[test]
fn second_lock_times_out_while_first_is_held() {
    smol::block_on(async {
        let td = tempdir().expect("create tempdir");
        let state = td.path().join("state");

        let _first = super::lock::acquire_switch_lock_with_timeout(&state, Duration::from_secs(1))
            .await
            .expect("acquire first lock");

        let err = super::lock::acquire_switch_lock_with_timeout(&state, Duration::from_millis(150))
            .await
            .expect_err("second lock should time out");

        assert!(matches!(err, AppError::LockTimeout { .. }));
    });
}

#[test]
fn lock_is_released_on_drop_without_deleting_lockfile() {
    smol::block_on(async {
        let td = tempdir().expect("create tempdir");
        let state = td.path().join("state");

        {
            let _first =
                super::lock::acquire_switch_lock_with_timeout(&state, Duration::from_secs(1))
                    .await
                    .expect("acquire first lock");
            let lock_text = fs::read_to_string(state.join("switch.lock"))
                .expect("read lock metadata while lock is held");
            assert!(lock_text.contains("pid="));
        }

        assert!(state.join("switch.lock").exists());

        let _second = super::lock::acquire_switch_lock_with_timeout(&state, Duration::from_secs(1))
            .await
            .expect("acquire lock after first drop");
    });
}

fn btreemap_theme(theme: &str) -> BTreeMap<String, String> {
    let mut selection = BTreeMap::new();
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
            json!({
                "path": path,
                "rules": [{ "source": source.to_string_lossy() }]
            })
        })
        .collect::<Vec<_>>();

    let text = serde_json::to_string_pretty(&json!({
        "version": 1,
        "home": home.to_string_lossy(),
        "facets": {
            "theme": {
                "default": "gruvbox",
                "variants": { "gruvbox": {}, "modus": {} }
            }
        },
        "defaultSelection": { "theme": "gruvbox" },
        "files": files,
        "hooks": { "reload": [] }
    }))
    .expect("serialize manifest");

    fs::write(manifest_path, text).expect("write manifest");
}

fn write_manifest_rules(manifest_path: &Path, home: &Path, path: &str, by_theme: &[(&str, &Path)]) {
    let rules = by_theme
        .iter()
        .map(|(theme, source)| {
            json!({
                "when": { "theme": [theme] },
                "source": source.to_string_lossy()
            })
        })
        .collect::<Vec<_>>();

    let text = serde_json::to_string_pretty(&json!({
        "version": 1,
        "home": home.to_string_lossy(),
        "facets": {
            "theme": {
                "default": "gruvbox",
                "variants": { "gruvbox": {}, "modus": {} }
            }
        },
        "defaultSelection": { "theme": "gruvbox" },
        "files": [{
            "path": path,
            "rules": rules
        }],
        "hooks": { "reload": [] }
    }))
    .expect("serialize manifest");

    fs::write(manifest_path, text).expect("write manifest");
}

fn assert_points_to(target: &Path, source: &Path) {
    let meta = fs::symlink_metadata(target).expect("target metadata");
    assert!(meta.file_type().is_symlink());

    let actual = fs::read_link(target).expect("read symlink target");
    assert_eq!(actual, source);
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
