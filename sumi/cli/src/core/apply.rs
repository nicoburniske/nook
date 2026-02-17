use super::{read_snapshot, unix_seconds_string, when_matches, write_json_atomic};
use crate::error::AppError;
use crate::model::{FileRule, Manifest, ManifestFile, Snapshot};
use std::collections::{BTreeMap, BTreeSet};
use std::io::ErrorKind;
use std::path::{Path, PathBuf};
use std::time::{SystemTime, UNIX_EPOCH};

#[derive(Debug, Clone, Copy)]
pub enum ConflictPolicy {
    Backup,
    Replace,
}

#[derive(Debug)]
pub struct ApplySummary {
    pub created: usize,
    pub updated: usize,
    pub removed: usize,
    pub unchanged: usize,
    pub failed: usize,
}

pub async fn apply(
    manifest: Manifest,
    home_dir: &Path,
    state_dir: &Path,
    set_overrides: &BTreeMap<String, String>,
    conflict_policy: ConflictPolicy,
) -> Result<ApplySummary, AppError> {
    let _ = manifest.version;

    let selection = resolve_selection(&manifest, set_overrides)?;
    let desired = collect_desired_map(&manifest.files, &selection, home_dir)?;

    let missing_sources = collect_missing_sources(&desired).await;
    if !missing_sources.is_empty() {
        return Err(AppError::MissingSources {
            paths: missing_sources.join(", "),
        });
    }

    smol::fs::create_dir_all(state_dir)
        .await
        .map_err(|source| AppError::CreateDir {
            path: state_dir.to_path_buf(),
            source,
        })?;

    let snapshot_path = state_dir.join("snapshot.json");
    let old_snapshot = read_snapshot(&snapshot_path, selection.clone()).await?;
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

        match remove_stale(conflict_policy, Path::new(target), expected_old).await {
            Ok(true) => removed += 1,
            Ok(false) => {}
            Err(err) => {
                failed += 1;
                log::error!("remove failed for '{}': {}", target, err);
            }
        }
    }

    for target in &update_paths {
        let expected_old = old_files
            .get(target)
            .expect("update path must exist in old map");
        let source = desired
            .get(target)
            .expect("update path must exist in desired map");

        match ensure_link(
            conflict_policy,
            Path::new(target),
            Path::new(source),
            Some(Path::new(expected_old)),
        )
        .await
        {
            Ok(true) => updated += 1,
            Ok(false) => {}
            Err(err) => {
                failed += 1;
                log::error!("update failed for '{}': {}", target, err);
            }
        }
    }

    for target in &create_paths {
        let source = desired
            .get(target)
            .expect("create path must exist in desired map");

        match ensure_link(conflict_policy, Path::new(target), Path::new(source), None).await {
            Ok(true) => created += 1,
            Ok(false) => {}
            Err(err) => {
                failed += 1;
                log::error!("create failed for '{}': {}", target, err);
            }
        }
    }

    let mut actual_files = BTreeMap::new();
    for (target, source) in desired {
        if path_points_to(Path::new(&target), Path::new(&source))
            .await
            .unwrap_or(false)
        {
            actual_files.insert(target, source);
        }
    }

    let snapshot = Snapshot {
        version: 1,
        selection,
        updated_at: unix_seconds_string(),
        files: actual_files,
    };
    write_json_atomic(&snapshot, &snapshot_path).await?;

    Ok(ApplySummary {
        created,
        updated,
        removed,
        unchanged,
        failed,
    })
}

fn resolve_selection(
    manifest: &Manifest,
    overrides: &BTreeMap<String, String>,
) -> Result<BTreeMap<String, String>, AppError> {
    let mut selection = manifest.default_selection.clone();

    for (facet_name, facet) in &manifest.facets {
        selection
            .entry(facet_name.clone())
            .or_insert_with(|| facet.default.clone());
    }

    for (facet, value) in overrides {
        let data = manifest
            .facets
            .get(facet)
            .ok_or_else(|| AppError::UnknownFacet {
                facet: facet.clone(),
            })?;

        if !data.variants.contains_key(value) {
            return Err(AppError::InvalidFacetValue {
                facet: facet.clone(),
                value: value.clone(),
            });
        }

        selection.insert(facet.clone(), value.clone());
    }

    Ok(selection)
}

fn collect_desired_map(
    files: &[ManifestFile],
    selection: &BTreeMap<String, String>,
    home: &Path,
) -> Result<BTreeMap<String, String>, AppError> {
    let mut desired = BTreeMap::new();
    let mut seen_paths = BTreeSet::new();

    for file in files {
        if !seen_paths.insert(file.path.clone()) {
            return Err(AppError::DuplicatePath {
                path: file.path.clone(),
            });
        }

        let maybe_rule = file.rules.iter().find(|rule| rule_matches(rule, selection));
        let Some(rule) = maybe_rule else {
            continue;
        };

        let target = home.join(&file.path);
        desired.insert(target.to_string_lossy().into_owned(), rule.source.clone());
    }

    Ok(desired)
}

fn rule_matches(rule: &FileRule, selection: &BTreeMap<String, String>) -> bool {
    when_matches(&rule.when, selection)
}

async fn collect_missing_sources(desired: &BTreeMap<String, String>) -> Vec<String> {
    let mut missing = Vec::new();
    for source in desired.values() {
        if smol::fs::metadata(Path::new(source)).await.is_err() {
            missing.push(source.clone());
        }
    }
    missing
}

async fn remove_stale(
    conflict_policy: ConflictPolicy,
    target: &Path,
    expected_old_source: &str,
) -> Result<bool, std::io::Error> {
    if !path_exists_or_symlink(target).await? {
        return Ok(false);
    }

    let expected = Path::new(expected_old_source);
    let matches_expected = path_points_to(target, expected).await.unwrap_or(false);
    if matches_expected {
        remove_target(target).await?;
        log::debug!("removed stale path '{}'", target.display());
        return Ok(true);
    }

    handle_conflict(conflict_policy, target).await?;
    Ok(true)
}

async fn ensure_link(
    conflict_policy: ConflictPolicy,
    target: &Path,
    source: &Path,
    expected_old_source: Option<&Path>,
) -> Result<bool, std::io::Error> {
    if smol::fs::metadata(source).await.is_err() {
        return Err(std::io::Error::new(
            std::io::ErrorKind::NotFound,
            format!("source does not exist: {}", source.display()),
        ));
    }

    if path_points_to(target, source).await.unwrap_or(false) {
        return Ok(false);
    }

    if path_exists_or_symlink(target).await? {
        if let Some(expected_old) = expected_old_source {
            if path_points_to(target, expected_old).await.unwrap_or(false) {
                remove_target(target).await?;
                log::debug!(
                    "removed managed target '{}' before relink",
                    target.display()
                );
            } else {
                handle_conflict(conflict_policy, target).await?;
            }
        } else {
            handle_conflict(conflict_policy, target).await?;
        }
    }

    if let Some(parent) = target.parent() {
        smol::fs::create_dir_all(parent).await?;
    }

    let tmp = tmp_link_path(target);
    if path_exists_or_symlink(&tmp).await? {
        remove_target(&tmp).await?;
    }

    smol::fs::unix::symlink(source, &tmp).await?;
    smol::fs::rename(&tmp, target).await?;
    log::debug!("linked '{}' -> '{}'", target.display(), source.display());
    Ok(true)
}

async fn handle_conflict(
    conflict_policy: ConflictPolicy,
    target: &Path,
) -> Result<(), std::io::Error> {
    match conflict_policy {
        ConflictPolicy::Replace => {
            remove_target(target).await?;
            log::debug!("replaced existing target '{}'", target.display());
        }
        ConflictPolicy::Backup => {
            let backup_path = backup_path_for(target).await?;
            smol::fs::rename(target, &backup_path).await?;
            log::warn!(
                "backed up existing target '{}' -> '{}'",
                target.display(),
                backup_path.display()
            );
        }
    }

    Ok(())
}

async fn backup_path_for(target: &Path) -> Result<PathBuf, std::io::Error> {
    let mut idx = 0u32;
    let epoch = SystemTime::now()
        .duration_since(UNIX_EPOCH)
        .map(|d| d.as_secs())
        .unwrap_or(0);

    loop {
        let candidate = PathBuf::from(format!("{}.sumi.bak.{}.{}", target.display(), epoch, idx));
        if !path_exists_or_symlink(&candidate).await? {
            return Ok(candidate);
        }

        idx = idx.saturating_add(1);
    }
}

async fn remove_target(path: &Path) -> Result<(), std::io::Error> {
    let metadata = match smol::fs::symlink_metadata(path).await {
        Ok(metadata) => metadata,
        Err(err) if err.kind() == ErrorKind::NotFound => return Ok(()),
        Err(err) => return Err(err),
    };

    if metadata.file_type().is_dir() {
        smol::fs::remove_dir_all(path).await
    } else {
        smol::fs::remove_file(path).await
    }
}

async fn path_exists_or_symlink(path: &Path) -> Result<bool, std::io::Error> {
    match smol::fs::symlink_metadata(path).await {
        Ok(_) => Ok(true),
        Err(err) if err.kind() == ErrorKind::NotFound => Ok(false),
        Err(err) => Err(err),
    }
}

async fn path_points_to(target: &Path, expected: &Path) -> Result<bool, std::io::Error> {
    let metadata = match smol::fs::symlink_metadata(target).await {
        Ok(metadata) => metadata,
        Err(err) if err.kind() == std::io::ErrorKind::NotFound => return Ok(false),
        Err(err) => return Err(err),
    };

    if !metadata.file_type().is_symlink() {
        return Ok(false);
    }

    let link = smol::fs::read_link(target).await?;
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
