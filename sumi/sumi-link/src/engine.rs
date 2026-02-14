use crate::cli::ConflictPolicyArg;
use crate::error::AppError;
use crate::manifest::{Manifest, Theme};
use crate::snapshot::Snapshot;
use log::{error, info, warn};
use std::collections::{BTreeMap, BTreeSet};
use std::fs;
use std::os::unix::fs::symlink;
use std::path::{Path, PathBuf};
use std::time::{SystemTime, UNIX_EPOCH};

#[derive(Debug, Clone, Copy)]
pub enum ConflictPolicy {
    Backup,
    Replace,
}

impl From<ConflictPolicyArg> for ConflictPolicy {
    fn from(value: ConflictPolicyArg) -> Self {
        match value {
            ConflictPolicyArg::Backup => Self::Backup,
            ConflictPolicyArg::Replace => Self::Replace,
        }
    }
}

#[derive(Debug)]
pub struct ApplySummary {
    pub created: usize,
    pub updated: usize,
    pub removed: usize,
    pub unchanged: usize,
    pub failed: usize,
}

#[derive(Debug)]
pub struct Engine {
    pub conflict_policy: ConflictPolicy,
}

impl Engine {
    pub fn apply(
        &self,
        manifest: Manifest,
        state_dir: &Path,
        theme_name: &str,
    ) -> Result<ApplySummary, AppError> {
        let home = manifest.home_path()?;
        let _ = manifest.version;
        let _ = &manifest.default_theme;

        let theme = manifest
            .themes
            .get(theme_name)
            .ok_or_else(|| AppError::MissingTheme {
                theme: theme_name.to_string(),
            })?;

        let desired = collect_desired_map(theme_name, theme, &home)?;

        fs::create_dir_all(state_dir).map_err(|source| AppError::CreateDir {
            path: state_dir.to_path_buf(),
            source,
        })?;

        let snapshot_path = state_dir.join("snapshot.json");
        let old_snapshot = Snapshot::read(&snapshot_path, theme_name.to_string())?;
        let old_files = old_snapshot.files;

        let old_keys: BTreeSet<String> = old_files.keys().cloned().collect();
        let new_keys: BTreeSet<String> = desired.keys().cloned().collect();

        let remove_paths: Vec<String> = old_keys.difference(&new_keys).cloned().collect();
        let create_paths: Vec<String> = new_keys.difference(&old_keys).cloned().collect();

        let mut unchanged = 0usize;
        let mut update_paths = Vec::new();
        for key in old_keys.intersection(&new_keys) {
            let old_source = old_files.get(key).expect("key exists in old map");
            let new_source = desired.get(key).expect("key exists in new map");
            if old_source == new_source {
                unchanged += 1;
            } else {
                update_paths.push(key.clone());
            }
        }

        let mut created = 0usize;
        let mut updated = 0usize;
        let mut removed = 0usize;
        let mut failed = 0usize;

        for target in &remove_paths {
            let expected_old = old_files
                .get(target)
                .expect("remove path must exist in old map");

            match self.remove_stale(Path::new(target), expected_old) {
                Ok(true) => removed += 1,
                Ok(false) => {}
                Err(err) => {
                    failed += 1;
                    error!("remove failed for '{}': {}", target, err);
                }
            }
        }

        for target in &update_paths {
            let source = desired
                .get(target)
                .expect("update path must exist in desired map");
            match self.ensure_link(Path::new(target), Path::new(source)) {
                Ok(true) => updated += 1,
                Ok(false) => {}
                Err(err) => {
                    failed += 1;
                    error!("update failed for '{}': {}", target, err);
                }
            }
        }

        for target in &create_paths {
            let source = desired
                .get(target)
                .expect("create path must exist in desired map");
            match self.ensure_link(Path::new(target), Path::new(source)) {
                Ok(true) => created += 1,
                Ok(false) => {}
                Err(err) => {
                    failed += 1;
                    error!("create failed for '{}': {}", target, err);
                }
            }
        }

        let mut actual_files = BTreeMap::new();
        for (target, source) in desired {
            if path_points_to(Path::new(&target), Path::new(&source)).unwrap_or(false) {
                actual_files.insert(target, source);
            }
        }

        let snapshot = Snapshot {
            version: 1,
            theme: theme_name.to_string(),
            updated_at: unix_seconds_string(),
            files: actual_files,
        };
        snapshot.write_atomic(&snapshot_path)?;

        Ok(ApplySummary {
            created,
            updated,
            removed,
            unchanged,
            failed,
        })
    }

    fn remove_stale(
        &self,
        target: &Path,
        expected_old_source: &str,
    ) -> Result<bool, std::io::Error> {
        if !target.exists() && !target.is_symlink() {
            return Ok(false);
        }

        let expected = Path::new(expected_old_source);
        let matches_expected = path_points_to(target, expected).unwrap_or(false);
        if matches_expected {
            remove_target(target)?;
            info!("removed stale path '{}'", target.display());
            return Ok(true);
        }

        self.handle_conflict(target)?;
        Ok(true)
    }

    fn ensure_link(&self, target: &Path, source: &Path) -> Result<bool, std::io::Error> {
        if !source.exists() {
            return Err(std::io::Error::new(
                std::io::ErrorKind::NotFound,
                format!("source does not exist: {}", source.display()),
            ));
        }

        if path_points_to(target, source).unwrap_or(false) {
            return Ok(false);
        }

        if target.exists() || target.is_symlink() {
            self.handle_conflict(target)?;
        }

        if let Some(parent) = target.parent() {
            fs::create_dir_all(parent)?;
        }

        let tmp = tmp_link_path(target);
        symlink(source, &tmp)?;
        fs::rename(&tmp, target)?;
        info!("linked '{}' -> '{}'", target.display(), source.display());
        Ok(true)
    }

    fn handle_conflict(&self, target: &Path) -> Result<(), std::io::Error> {
        match self.conflict_policy {
            ConflictPolicy::Replace => {
                remove_target(target)?;
                info!("replaced existing target '{}'", target.display());
            }
            ConflictPolicy::Backup => {
                let backup_path = backup_path_for(target);
                fs::rename(target, &backup_path)?;
                warn!(
                    "backed up existing target '{}' -> '{}'",
                    target.display(),
                    backup_path.display()
                );
            }
        }
        Ok(())
    }
}

fn collect_desired_map(
    theme_name: &str,
    theme: &Theme,
    home: &Path,
) -> Result<BTreeMap<String, String>, AppError> {
    let mut desired = BTreeMap::new();
    let mut seen_paths = BTreeSet::new();
    for file in &theme.files {
        let _ = file.executable;
        if !seen_paths.insert(file.path.clone()) {
            return Err(AppError::DuplicatePath {
                theme: theme_name.to_string(),
                path: file.path.clone(),
            });
        }

        let target = home.join(&file.path);
        desired.insert(target.to_string_lossy().into_owned(), file.source.clone());
    }
    Ok(desired)
}

#[cfg(test)]
mod tests {
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

        let snapshot = Snapshot::read(&state.join("snapshot.json"), "gruvbox".to_string())
            .expect("read snapshot");
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
    fn missing_source_fails_entry_but_continues() {
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
        let summary = engine
            .apply(
                Manifest::load(&manifest_path).expect("load manifest"),
                &state,
                "gruvbox",
            )
            .expect("apply should continue");

        assert_eq!(summary.failed, 1);
        assert_points_to(&home.join(".config/app/a.conf"), &src);
        assert!(!home.join(".config/app/b.conf").exists());

        let snapshot = Snapshot::read(&state.join("snapshot.json"), "gruvbox".to_string())
            .expect("read snapshot");
        assert_eq!(snapshot.files.len(), 1);
        assert!(snapshot
            .files
            .contains_key(home.join(".config/app/a.conf").to_string_lossy().as_ref()));
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
  "version": 2,
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
  "version": 2,
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
}

fn tmp_link_path(target: &Path) -> PathBuf {
    let suffix = SystemTime::now()
        .duration_since(UNIX_EPOCH)
        .map(|d| d.as_nanos())
        .unwrap_or(0);
    PathBuf::from(format!(
        "{}.sumi.tmp.{}.{}",
        target.display(),
        std::process::id(),
        suffix
    ))
}

fn backup_path_for(target: &Path) -> PathBuf {
    let mut idx = 0u32;
    let epoch = SystemTime::now()
        .duration_since(UNIX_EPOCH)
        .map(|d| d.as_secs())
        .unwrap_or(0);

    loop {
        let candidate = PathBuf::from(format!("{}.sumi.bak.{}.{}", target.display(), epoch, idx));
        if !candidate.exists() && !candidate.is_symlink() {
            return candidate;
        }
        idx = idx.saturating_add(1);
    }
}

fn remove_target(path: &Path) -> Result<(), std::io::Error> {
    if !path.exists() && !path.is_symlink() {
        return Ok(());
    }

    let metadata = fs::symlink_metadata(path)?;
    if metadata.file_type().is_dir() {
        fs::remove_dir_all(path)
    } else {
        fs::remove_file(path)
    }
}

fn path_points_to(target: &Path, expected: &Path) -> Result<bool, std::io::Error> {
    let metadata = match fs::symlink_metadata(target) {
        Ok(metadata) => metadata,
        Err(err) if err.kind() == std::io::ErrorKind::NotFound => return Ok(false),
        Err(err) => return Err(err),
    };

    if !metadata.file_type().is_symlink() {
        return Ok(false);
    }

    let link = fs::read_link(target)?;
    let resolved = if link.is_absolute() {
        link
    } else {
        match target.parent() {
            Some(parent) => parent.join(link),
            None => link,
        }
    };

    Ok(resolved == expected)
}

fn unix_seconds_string() -> String {
    SystemTime::now()
        .duration_since(UNIX_EPOCH)
        .map(|d| d.as_secs().to_string())
        .unwrap_or_else(|_| "0".to_string())
}
