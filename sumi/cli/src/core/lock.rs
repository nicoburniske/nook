use crate::error::AppError;
use futures_lite::io::AsyncWriteExt;
use log::warn;
use std::io::ErrorKind;
use std::path::{Path, PathBuf};
use std::time::Duration;

#[derive(Debug)]
pub struct SwitchLock {
    path: PathBuf,
}

impl Drop for SwitchLock {
    fn drop(&mut self) {
        if let Err(source) = std::fs::remove_file(&self.path) {
            if source.kind() != ErrorKind::NotFound {
                warn!(
                    "failed to remove switch lock '{}': {}",
                    self.path.display(),
                    source
                );
            }
        }
    }
}

pub async fn acquire_switch_lock(state_dir: &Path) -> Result<SwitchLock, AppError> {
    smol::fs::create_dir_all(state_dir)
        .await
        .map_err(|source| AppError::CreateDir {
            path: state_dir.to_path_buf(),
            source,
        })?;

    let lock_path = state_dir.join("switch.lock");

    loop {
        match smol::fs::OpenOptions::new()
            .create_new(true)
            .write(true)
            .open(&lock_path)
            .await
        {
            Ok(mut file) => {
                let payload = format!("{}\n", std::process::id());
                file.write_all(payload.as_bytes())
                    .await
                    .map_err(|source| AppError::WriteFile {
                        path: lock_path.clone(),
                        source,
                    })?;
                return Ok(SwitchLock { path: lock_path });
            }
            Err(source) if source.kind() == ErrorKind::AlreadyExists => {
                smol::Timer::after(Duration::from_millis(100)).await;
            }
            Err(source) => {
                return Err(AppError::WriteFile {
                    path: lock_path,
                    source,
                });
            }
        }
    }
}
