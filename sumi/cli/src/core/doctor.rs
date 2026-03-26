use crate::compile::CompiledManifest;
use crate::dispatch::resolve_dispatch;
use crate::manifest::Selection;
use std::io::ErrorKind;
use std::path::{Path, PathBuf};

#[derive(Debug)]
pub struct DoctorReport {
    pub failures: Vec<String>,
}

pub async fn doctor(
    manifest: &CompiledManifest,
    home_dir: &Path,
    selection: &Selection,
) -> DoctorReport {
    let mut failures = Vec::new();

    for file in &manifest.files {
        let Some(source) = resolve_dispatch(&file.dispatch, selection) else {
            continue;
        };

        if file.path.is_empty() {
            continue;
        }

        if smol::fs::metadata(source).await.is_err() {
            failures.push(format!("missing source: {}", source.display()));
        }

        let dest = home_dir.join(&file.path);
        match smol::fs::symlink_metadata(&dest).await {
            Ok(metadata) => {
                if !metadata.file_type().is_symlink() {
                    failures.push(format!("non-symlink destination: {}", dest.display()));
                } else if let Err(message) = verify_symlink_target(&dest, source).await {
                    failures.push(message);
                }
            }
            Err(source) if source.kind() == ErrorKind::NotFound => {
                failures.push(format!("missing destination: {}", dest.display()));
            }
            Err(source) => {
                failures.push(format!(
                    "failed to inspect destination {}: {}",
                    dest.display(),
                    source
                ));
            }
        }
    }

    DoctorReport { failures }
}

async fn verify_symlink_target(dest: &Path, expected: &Path) -> Result<(), String> {
    let actual = smol::fs::read_link(dest)
        .await
        .map_err(|source| format!("failed to read destination {}: {}", dest.display(), source))?;

    let resolved = resolve_link_target(dest, actual);
    if resolved == expected {
        Ok(())
    } else {
        Err(format!(
            "wrong symlink target: {} -> {} (expected {})",
            dest.display(),
            resolved.display(),
            expected.display()
        ))
    }
}

fn resolve_link_target(dest: &Path, link: PathBuf) -> PathBuf {
    if link.is_absolute() {
        return link;
    }

    match dest.parent() {
        Some(parent) => parent.join(link),
        None => link,
    }
}
