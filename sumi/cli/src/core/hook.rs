use super::when_matches;
use crate::model::{Hook, Manifest};
use smol::process::Command;
use std::collections::BTreeMap;

#[derive(Debug)]
pub struct HookResult {
    pub ok: bool,
    pub label: String,
    pub output: String,
}

pub async fn run_reload_hooks(
    manifest: &Manifest,
    selection: &BTreeMap<String, String>,
) -> Vec<HookResult> {
    let matching: Vec<Hook> = manifest
        .hooks
        .reload
        .iter()
        .filter(|hook| when_matches(&hook.when, selection))
        .cloned()
        .collect();

    let mut tasks = Vec::new();
    for hook in matching {
        tasks.push(smol::spawn(async move { run_hook(hook).await }));
    }

    let mut results = Vec::new();
    for task in tasks {
        results.push(task.await);
    }

    results
}

async fn run_hook(hook: Hook) -> HookResult {
    let label = hook
        .registration
        .strip_prefix("program-")
        .unwrap_or(&hook.registration)
        .to_string();

    if hook.command.trim().is_empty() {
        return HookResult {
            ok: true,
            label,
            output: String::new(),
        };
    }

    match Command::new("bash")
        .arg("-lc")
        .arg(&hook.command)
        .output()
        .await
    {
        Ok(output) => {
            let stderr = String::from_utf8_lossy(&output.stderr).trim().to_string();
            let stdout = String::from_utf8_lossy(&output.stdout).trim().to_string();
            let combined = if stderr.is_empty() {
                stdout
            } else if stdout.is_empty() {
                stderr
            } else {
                format!("{stderr}\n{stdout}")
            };

            HookResult {
                ok: output.status.success(),
                label,
                output: combined,
            }
        }
        Err(err) => HookResult {
            ok: false,
            label,
            output: format!("failed to run '{}': {}", hook.command, err),
        },
    }
}
