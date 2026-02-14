use crate::error::AppError;
use serde::{Deserialize, Serialize};
use std::collections::BTreeMap;
use std::fs;
use std::path::Path;
use std::time::{SystemTime, UNIX_EPOCH};

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Snapshot {
    pub version: u64,
    pub theme: String,
    #[serde(rename = "updatedAt")]
    pub updated_at: String,
    pub files: BTreeMap<String, String>,
}

impl Snapshot {
    pub fn empty(theme: String) -> Self {
        Self {
            version: 1,
            theme,
            updated_at: now_rfc3339_like(),
            files: BTreeMap::new(),
        }
    }

    pub fn read(path: &Path, theme: String) -> Result<Self, AppError> {
        if !path.exists() {
            return Ok(Self::empty(theme));
        }

        let text = fs::read_to_string(path).map_err(|source| AppError::ReadFile {
            path: path.to_path_buf(),
            source,
        })?;

        serde_json::from_str(&text).map_err(|source| AppError::ParseJson {
            path: path.to_path_buf(),
            source,
        })
    }

    pub fn write_atomic(&self, path: &Path) -> Result<(), AppError> {
        let parent = path.parent().ok_or_else(|| AppError::WriteFile {
            path: path.to_path_buf(),
            source: std::io::Error::new(std::io::ErrorKind::Other, "missing parent directory"),
        })?;

        fs::create_dir_all(parent).map_err(|source| AppError::CreateDir {
            path: parent.to_path_buf(),
            source,
        })?;

        let mut tmp = path.to_path_buf();
        tmp.set_extension(format!("tmp.{}", std::process::id()));

        let serialized = serde_json::to_vec_pretty(self).map_err(AppError::SerializeSnapshot)?;

        fs::write(&tmp, serialized).map_err(|source| AppError::WriteFile {
            path: tmp.clone(),
            source,
        })?;

        fs::rename(&tmp, path).map_err(|source| AppError::RenamePath {
            from: tmp,
            to: path.to_path_buf(),
            source,
        })
    }
}

fn now_rfc3339_like() -> String {
    let secs = match SystemTime::now().duration_since(UNIX_EPOCH) {
        Ok(duration) => duration.as_secs(),
        Err(_) => 0,
    };
    format!("{secs}")
}
