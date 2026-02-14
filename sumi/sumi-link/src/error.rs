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

    #[error("theme '{theme}' was not found in manifest")]
    MissingTheme { theme: String },

    #[error("duplicate file path '{path}' in theme '{theme}'")]
    DuplicatePath { theme: String, path: String },

    #[error("manifest contains invalid home directory '{home}'")]
    InvalidHome { home: String },

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
