use crate::cli::ConflictPolicyArg;
use crate::error::AppError;
use crate::manifest::{Manifest, ThemeFile};
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

        let desired = collect_desired_map(theme_name, &theme.files, &home)?;

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
    theme_files: &[ThemeFile],
    home: &Path,
) -> Result<BTreeMap<String, String>, AppError> {
    let mut desired = BTreeMap::new();
    let mut seen_paths = BTreeSet::new();

    for file in theme_files {
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

#[cfg(test)]
#[path = "engine_tests.rs"]
mod tests;
