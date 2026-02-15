use std::path::PathBuf;
use thiserror::Error;

#[derive(Debug, Error)]
pub enum AppError {
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

    #[error("invalid --set value '{value}', expected key=value")]
    InvalidSelectionSet { value: String },

    #[error("unknown facet '{facet}'")]
    UnknownFacet { facet: String },

    #[error("invalid value '{value}' for facet '{facet}'")]
    InvalidFacetValue { facet: String, value: String },

    #[error("duplicate managed file path '{path}' in manifest")]
    DuplicatePath { path: String },

    #[error("manifest contains invalid home directory '{home}'")]
    InvalidHome { home: String },

    #[error("manifest contains missing source paths: {paths}")]
    MissingSources { paths: String },

    #[error("failed to serialize snapshot: {0}")]
    SerializeSnapshot(#[source] serde_json::Error),

    #[error("failed to write file {path}: {source}")]
    WriteFile {
        path: PathBuf,
        #[source]
        source: std::io::Error,
    },

    #[error("failed to rename {from} to {to}: {source}")]
    RenamePath {
        from: PathBuf,
        to: PathBuf,
        #[source]
        source: std::io::Error,
    },
}
