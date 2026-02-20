use crate::error::AppError;
use std::io::{ErrorKind, Seek, SeekFrom, Write};
use std::path::{Path, PathBuf};
use std::time::{Duration, SystemTime, UNIX_EPOCH};

#[cfg(unix)]
use std::os::fd::AsRawFd;

const LOCK_RETRY_DELAY: Duration = Duration::from_millis(100);
const LOCK_WAIT_TIMEOUT: Duration = Duration::from_secs(10);

#[cfg(unix)]
const LOCK_EX: std::os::raw::c_int = 2;
#[cfg(unix)]
const LOCK_NB: std::os::raw::c_int = 4;
#[cfg(unix)]
const LOCK_UN: std::os::raw::c_int = 8;

#[cfg(unix)]
unsafe extern "C" {
    fn flock(fd: std::os::raw::c_int, operation: std::os::raw::c_int) -> std::os::raw::c_int;
}

#[derive(Debug)]
pub struct SwitchLock {
    path: PathBuf,
    file: std::fs::File,
}

impl Drop for SwitchLock {
    fn drop(&mut self) {
        if let Err(source) = unlock_file(&self.file) {
            log::warn!(
                "failed to unlock switch lock '{}': {}",
                self.path.display(),
                source
            );
        }
    }
}

pub async fn acquire_switch_lock(state_dir: &Path) -> Result<SwitchLock, AppError> {
    acquire_switch_lock_with_timeout(state_dir, LOCK_WAIT_TIMEOUT).await
}

pub(crate) async fn acquire_switch_lock_with_timeout(
    state_dir: &Path,
    timeout: Duration,
) -> Result<SwitchLock, AppError> {
    smol::fs::create_dir_all(state_dir)
        .await
        .map_err(|source| AppError::CreateDir {
            path: state_dir.to_path_buf(),
            source,
        })?;

    let lock_path = state_dir.join("switch.lock");
    let mut file = std::fs::OpenOptions::new()
        .create(true)
        .read(true)
        .write(true)
        .open(&lock_path)
        .map_err(|source| AppError::WriteFile {
            path: lock_path.clone(),
            source,
        })?;

    let started = std::time::Instant::now();

    loop {
        match try_lock_exclusive(&file) {
            Ok(()) => {
                write_lock_metadata(&mut file).map_err(|source| AppError::WriteFile {
                    path: lock_path.clone(),
                    source,
                })?;
                return Ok(SwitchLock {
                    path: lock_path,
                    file,
                });
            }
            Err(source) if source.kind() == ErrorKind::WouldBlock => {
                if started.elapsed() >= timeout {
                    return Err(AppError::LockTimeout {
                        path: lock_path,
                        waited_ms: timeout.as_millis() as u64,
                    });
                }
                smol::Timer::after(LOCK_RETRY_DELAY).await;
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

fn write_lock_metadata(file: &mut std::fs::File) -> std::io::Result<()> {
    file.set_len(0)?;
    file.seek(SeekFrom::Start(0))?;

    let now = SystemTime::now()
        .duration_since(UNIX_EPOCH)
        .map(|d| d.as_secs())
        .unwrap_or(0);
    let payload = format!("pid={}\nstarted_at={}\n", std::process::id(), now);
    file.write_all(payload.as_bytes())?;
    file.flush()?;
    Ok(())
}

fn try_lock_exclusive(file: &std::fs::File) -> std::io::Result<()> {
    #[cfg(unix)]
    {
        let rc = unsafe { flock(file.as_raw_fd(), LOCK_EX | LOCK_NB) };
        if rc == 0 {
            Ok(())
        } else {
            Err(std::io::Error::last_os_error())
        }
    }

    #[cfg(not(unix))]
    {
        let _ = file;
        Err(std::io::Error::new(
            ErrorKind::Unsupported,
            "switch lock is only implemented for unix targets",
        ))
    }
}

fn unlock_file(file: &std::fs::File) -> std::io::Result<()> {
    #[cfg(unix)]
    {
        let rc = unsafe { flock(file.as_raw_fd(), LOCK_UN) };
        if rc == 0 {
            Ok(())
        } else {
            Err(std::io::Error::last_os_error())
        }
    }

    #[cfg(not(unix))]
    {
        let _ = file;
        Ok(())
    }
}
