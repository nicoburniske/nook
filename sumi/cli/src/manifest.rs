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
    #[serde(rename = "variantRoots", default)]
    pub variant_roots: BTreeMap<String, BTreeMap<String, PathBuf>>,
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
    pub source: FileSource,
}

#[derive(Debug, Clone, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct ManifestHook {
    pub name: String,
    pub watch: String,
    pub command: HookCommand,
}

#[derive(Debug, Clone, Deserialize)]
#[serde(tag = "kind", rename_all = "lowercase", deny_unknown_fields)]
pub enum FileSource {
    Static { path: PathBuf },
    Facet { facet: String },
}

#[derive(Debug, Clone, Deserialize)]
#[serde(tag = "kind", rename_all = "lowercase", deny_unknown_fields)]
pub enum HookCommand {
    Static {
        value: String,
    },
    Facet {
        facet: String,
        variants: BTreeMap<String, String>,
    },
}
