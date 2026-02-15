use crate::error::AppError;
use serde::Deserialize;
use std::collections::HashMap;
use std::fs;
use std::path::{Path, PathBuf};

#[derive(Debug, Deserialize)]
pub struct Manifest {
    pub version: u64,
    pub home: String,
    #[serde(rename = "defaultTheme")]
    pub default_theme: String,
    pub themes: HashMap<String, Theme>,
}

#[derive(Debug, Deserialize)]
pub struct Theme {
    #[serde(default)]
    pub files: Vec<ThemeFile>,
}

#[derive(Debug, Deserialize)]
pub struct ThemeFile {
    pub path: String,
    pub source: String,
    pub executable: Option<bool>,
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
