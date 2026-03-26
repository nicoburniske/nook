use std::path::PathBuf;
use thiserror::Error;

#[derive(Debug, Error)]
pub enum AppError {
    #[error("sumi: manifest not configured. pass --manifest or set SUMI_MANIFEST")]
    ManifestNotConfigured,

    #[error("sumi: manifest does not exist: {path}")]
    ManifestMissing { path: PathBuf },

    #[error("sumi: could not resolve home directory")]
    ResolveHomeDirectory,

    #[error("sumi: invalid conflict policy '{value}', expected backup or replace")]
    InvalidConflictPolicy { value: String },

    #[error("sumi: invalid selection value '{value}', expected facet=value")]
    InvalidSelectionSet { value: String },

    #[error("sumi: unknown facet '{facet}'")]
    UnknownFacet { facet: String },

    #[error("sumi: invalid value '{value}' for facet '{facet}'")]
    InvalidFacetValue { facet: String, value: String },

    #[error("duplicate managed file path '{path}' in manifest")]
    DuplicatePath { path: String },

    #[error("manifest contains invalid home directory '{home}'")]
    InvalidHome { home: String },

    #[error("invalid manifest: {message}")]
    InvalidManifest { message: String },

    #[error("manifest contains missing source paths: {paths}")]
    MissingSources { paths: String },

    #[error("failed to read file {path}: {source}")]
    ReadFile {
        path: PathBuf,
        #[source]
        source: std::io::Error,
    },

    #[error("failed to parse JSON file {path}: {source}")]
    ParseJson {
        path: PathBuf,
        #[source]
        source: serde_json::Error,
    },

    #[error("failed to create directory {path}: {source}")]
    CreateDir {
        path: PathBuf,
        #[source]
        source: std::io::Error,
    },

    #[error("failed to write file {path}: {source}")]
    WriteFile {
        path: PathBuf,
        #[source]
        source: std::io::Error,
    },

    #[error("timed out waiting for switch lock {path} after {waited_ms}ms")]
    LockTimeout { path: PathBuf, waited_ms: u64 },

    #[error("failed to rename {from} to {to}: {source}")]
    RenamePath {
        from: PathBuf,
        to: PathBuf,
        #[source]
        source: std::io::Error,
    },

    #[error("failed to serialize JSON: {0}")]
    SerializeJson(#[source] serde_json::Error),
}
