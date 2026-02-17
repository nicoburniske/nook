use serde::{Deserialize, Serialize};
use serde_json::Value;
use std::collections::BTreeMap;

#[derive(Debug, Clone, Deserialize)]
pub struct Manifest {
    pub version: u64,
    pub home: String,
    #[serde(default)]
    pub facets: BTreeMap<String, Facet>,
    #[serde(rename = "defaultSelection", default)]
    pub default_selection: BTreeMap<String, String>,
    #[serde(default)]
    pub files: Vec<ManifestFile>,
    #[serde(default)]
    pub hooks: ManifestHooks,
}

#[derive(Debug, Clone, Deserialize)]
pub struct Facet {
    pub default: String,
    #[serde(default)]
    pub variants: BTreeMap<String, Value>,
}

#[derive(Debug, Clone, Deserialize)]
pub struct ManifestFile {
    pub path: String,
    #[allow(dead_code)]
    pub executable: Option<bool>,
    #[serde(default)]
    pub rules: Vec<FileRule>,
}

#[derive(Debug, Clone, Deserialize)]
pub struct FileRule {
    #[serde(default)]
    pub when: BTreeMap<String, Vec<String>>,
    pub source: String,
}

#[derive(Debug, Clone, Default, Deserialize)]
pub struct ManifestHooks {
    #[serde(default)]
    pub reload: Vec<Hook>,
}

#[derive(Debug, Clone, Deserialize)]
pub struct Hook {
    #[serde(default)]
    pub command: String,
    #[serde(default)]
    pub registration: String,
    #[serde(default)]
    pub when: BTreeMap<String, Vec<String>>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Snapshot {
    pub version: u64,
    pub selection: BTreeMap<String, String>,
    #[serde(rename = "updatedAt")]
    pub updated_at: String,
    pub files: BTreeMap<String, String>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct CurrentSelection {
    pub selection: BTreeMap<String, String>,
    #[serde(rename = "switchedAt")]
    pub switched_at: String,
}
