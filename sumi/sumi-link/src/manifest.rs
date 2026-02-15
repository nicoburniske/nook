use crate::error::AppError;
use serde::Deserialize;
use serde_json::Value;
use std::collections::{BTreeMap, HashMap};
use std::fs;
use std::path::{Path, PathBuf};

#[derive(Debug, Deserialize)]
pub struct Manifest {
    pub version: u64,
    pub home: String,
    pub facets: HashMap<String, Facet>,
    #[serde(rename = "defaultSelection")]
    pub default_selection: BTreeMap<String, String>,
    pub files: Vec<ManifestFile>,
}

#[derive(Debug, Deserialize)]
pub struct Facet {
    pub default: String,
    pub variants: HashMap<String, Value>,
}

#[derive(Debug, Deserialize)]
pub struct ManifestFile {
    pub path: String,
    #[allow(dead_code)]
    pub executable: Option<bool>,
    #[serde(default)]
    pub rules: Vec<FileRule>,
}

#[derive(Debug, Deserialize)]
pub struct FileRule {
    #[serde(default)]
    pub when: HashMap<String, Vec<String>>,
    pub source: String,
}

impl Manifest {
    pub fn load(path: &Path) -> Result<Self, AppError> {
        let text = fs::read_to_string(path).map_err(|source| AppError::ReadFile {
            path: path.to_path_buf(),
            source,
        })?;

        serde_json::from_str(&text).map_err(|source| AppError::ParseJson {
            path: path.to_path_buf(),
            source,
        })
    }

    pub fn home_path(&self) -> Result<PathBuf, AppError> {
        if !self.home.starts_with('/') {
            return Err(AppError::InvalidHome {
                home: self.home.clone(),
            });
        }

        Ok(PathBuf::from(&self.home))
    }
}
