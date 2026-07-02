pub mod apply;
pub mod doctor;
pub mod hook;
pub mod lock;

use crate::compile::{compile_manifest, CompiledManifest};
use crate::error::AppError;
use crate::manifest::Selection;
use crate::state::{CurrentSelection, Snapshot};
use serde::Serialize;
use std::collections::BTreeMap;
use std::io::ErrorKind;
use std::path::Path;
use std::time::{SystemTime, UNIX_EPOCH};

pub use apply::{apply, ApplySummary, ConflictPolicy};
pub use doctor::doctor;
pub use hook::run_reload_hooks;
pub use lock::acquire_switch_lock;

pub async fn load_manifest(path: &Path) -> Result<CompiledManifest, AppError> {
    let bytes = smol::fs::read(path)
        .await
        .map_err(|source| AppError::ReadFile {
            path: path.to_path_buf(),
            source,
        })?;

    let manifest = serde_json::from_slice(&bytes).map_err(|source| AppError::ParseJson {
        path: path.to_path_buf(),
        source,
    })?;

    compile_manifest(manifest)
}

pub async fn read_snapshot(path: &Path, selection: Selection) -> Result<Snapshot, AppError> {
    let bytes = match smol::fs::read(path).await {
        Ok(bytes) => bytes,
        Err(source) if source.kind() == ErrorKind::NotFound => {
            return Ok(Snapshot {
                version: 2,
                selection,
                updated_at: unix_seconds_string(),
                files: Vec::new(),
            });
        }
        Err(source) => {
            return Err(AppError::ReadFile {
                path: path.to_path_buf(),
                source,
            });
        }
    };

    serde_json::from_slice(&bytes).map_err(|source| AppError::ParseJson {
        path: path.to_path_buf(),
        source,
    })
}

pub async fn read_current_selection(path: &Path) -> Result<Option<CurrentSelection>, AppError> {
    let bytes = match smol::fs::read(path).await {
        Ok(bytes) => bytes,
        Err(source) if source.kind() == ErrorKind::NotFound => return Ok(None),
        Err(source) => {
            return Err(AppError::ReadFile {
                path: path.to_path_buf(),
                source,
            });
        }
    };

    serde_json::from_slice(&bytes)
        .map(Some)
        .map_err(|source| AppError::ParseJson {
            path: path.to_path_buf(),
            source,
        })
}

pub fn parse_selection_overrides(items: &[String]) -> Result<BTreeMap<String, String>, AppError> {
    let mut out = BTreeMap::new();

    for item in items {
        let Some((key, value)) = item.split_once('=') else {
            return Err(AppError::InvalidSelectionSet {
                value: item.clone(),
            });
        };

        if key.is_empty() || value.is_empty() {
            return Err(AppError::InvalidSelectionSet {
                value: item.clone(),
            });
        }

        out.insert(key.to_string(), value.to_string());
    }

    Ok(out)
}

pub fn validate_selection_overrides(
    manifest: &CompiledManifest,
    overrides: &Selection,
) -> Result<(), AppError> {
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
    }

    Ok(())
}

pub fn normalize_selection(manifest: &CompiledManifest, selection: &Selection) -> Selection {
    let mut out = Selection::new();

    for (facet_name, facet) in &manifest.facets {
        if facet.variants.is_empty() {
            continue;
        }

        let fallback = manifest
            .default_selection
            .get(facet_name)
            .cloned()
            .unwrap_or_else(|| facet.default.clone());

        let candidate = selection
            .get(facet_name)
            .cloned()
            .unwrap_or_else(|| fallback.clone());

        let chosen = if facet.variants.contains_key(&candidate) {
            candidate
        } else {
            fallback
        };

        out.insert(facet_name.clone(), chosen);
    }

    out
}

pub async fn get_selection(
    manifest: &CompiledManifest,
    state_dir: &Path,
) -> Result<Selection, AppError> {
    let current_path = state_dir.join("current.json");
    let selection = match read_current_selection(&current_path).await? {
        Some(current) => current.selection,
        None => manifest.default_selection.clone(),
    };

    Ok(normalize_selection(manifest, &selection))
}

pub async fn write_selection(state_dir: &Path, selection: &Selection) -> Result<(), AppError> {
    let current = CurrentSelection {
        selection: selection.clone(),
        switched_at: unix_seconds_string(),
    };

    write_json_atomic(&current, &state_dir.join("current.json")).await
}

pub(crate) fn unix_seconds_string() -> String {
    SystemTime::now()
        .duration_since(UNIX_EPOCH)
        .map(|d| d.as_secs().to_string())
        .unwrap_or_else(|_| "0".to_string())
}

pub(crate) async fn write_json_atomic<T: Serialize>(
    value: &T,
    path: &Path,
) -> Result<(), AppError> {
    let parent = path.parent().ok_or_else(|| AppError::WriteFile {
        path: path.to_path_buf(),
        source: std::io::Error::new(std::io::ErrorKind::Other, "missing parent directory"),
    })?;

    smol::fs::create_dir_all(parent)
        .await
        .map_err(|source| AppError::CreateDir {
            path: parent.to_path_buf(),
            source,
        })?;

    let mut tmp = path.to_path_buf();
    tmp.set_extension(format!("tmp.{}", std::process::id()));

    let serialized = serde_json::to_vec_pretty(value).map_err(AppError::SerializeJson)?;

    smol::fs::write(&tmp, serialized)
        .await
        .map_err(|source| AppError::WriteFile {
            path: tmp.clone(),
            source,
        })?;

    smol::fs::rename(&tmp, path)
        .await
        .map_err(|source| AppError::RenamePath {
            from: tmp,
            to: path.to_path_buf(),
            source,
        })
}

#[cfg(test)]
mod tests;
