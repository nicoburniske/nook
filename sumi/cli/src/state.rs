use crate::manifest::Selection;
use serde::{Deserialize, Serialize};
use std::collections::BTreeMap;
use std::path::PathBuf;

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Eq)]
pub struct ManagedFile {
    pub target: PathBuf,
    pub source: PathBuf,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Snapshot {
    pub version: u64,
    pub selection: Selection,
    pub updated_at: String,
    pub files: Vec<ManagedFile>,
}

impl Snapshot {
    pub fn file_map(&self) -> BTreeMap<PathBuf, PathBuf> {
        self.files
            .iter()
            .map(|file| (file.target.clone(), file.source.clone()))
            .collect()
    }
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct CurrentSelection {
    pub selection: Selection,
    pub switched_at: String,
}
