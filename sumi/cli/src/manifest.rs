use crate::dispatch::Dispatch;
use serde::Deserialize;
use serde_json::{Map, Value};
use std::collections::BTreeMap;
use std::path::PathBuf;

pub type Selection = BTreeMap<String, String>;
pub type VariantMeta = Map<String, Value>;

#[derive(Debug, Clone, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct Manifest {
    pub version: u64,
    pub home: PathBuf,
    #[serde(default)]
    pub facets: BTreeMap<String, FacetDef>,
    #[serde(rename = "defaultSelection", default)]
    pub default_selection: Selection,
    #[serde(default)]
    pub files: Vec<ManifestFile>,
    #[serde(default)]
    pub hooks: Vec<ManifestHook>,
}

#[derive(Debug, Clone, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct FacetDef {
    pub default: String,
    #[serde(default)]
    pub variants: BTreeMap<String, VariantMeta>,
}

#[derive(Debug, Clone, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct ManifestFile {
    pub path: String,
    pub dispatch: Dispatch<PathBuf>,
}

#[derive(Debug, Clone, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct ManifestHook {
    pub name: String,
    pub watch: Vec<String>,
    pub dispatch: Dispatch<String>,
}
