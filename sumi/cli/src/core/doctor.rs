use super::when_matches;
use crate::model::Manifest;
use std::collections::BTreeMap;
use std::io::ErrorKind;
use std::path::Path;

#[derive(Debug)]
pub struct DoctorReport {
    pub failures: Vec<String>,
}

pub async fn doctor(
    manifest: &Manifest,
    home_dir: &Path,
    selection: &BTreeMap<String, String>,
) -> DoctorReport {
    let mut failures = Vec::new();

    for file in &manifest.files {
        let selected_rule = file
            .rules
            .iter()
            .find(|rule| when_matches(&rule.when, selection));
        let Some(rule) = selected_rule else {
            continue;
        };

        if file.path.is_empty() {
            continue;
        }

        let source = Path::new(&rule.source);
        if smol::fs::metadata(source).await.is_err() {
            failures.push(format!("missing source: {}", source.display()));
        }

        let dest = home_dir.join(&file.path);
        match smol::fs::symlink_metadata(&dest).await {
            Ok(metadata) => {
                if !metadata.file_type().is_symlink() {
                    failures.push(format!("non-symlink destination: {}", dest.display()));
                }
            }
            Err(source) if source.kind() == ErrorKind::NotFound => {}
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
