use crate::compile::{CompiledHook, CompiledManifest};
use crate::dispatch::resolve_dispatch;
use crate::manifest::Selection;
use smol::process::Command;
use std::collections::BTreeSet;

#[derive(Debug)]
pub struct HookResult {
    pub ok: bool,
    pub label: String,
    pub output: String,
}

pub async fn run_reload_hooks(
    manifest: &CompiledManifest,
    selection: &Selection,
    changed_facets: &BTreeSet<String>,
) -> Vec<HookResult> {
    let matching: Vec<(String, String)> = manifest
        .hooks
        .iter()
        .filter_map(|hook| resolve_hook(hook, selection, changed_facets))
        .collect();

    let mut tasks = Vec::new();
    for (label, command) in matching {
        tasks.push(smol::spawn(async move { run_hook(label, command).await }));
    }

    let mut results = Vec::new();
    for task in tasks {
        results.push(task.await);
    }

    results
}

fn resolve_hook(
    hook: &CompiledHook,
    selection: &Selection,
    changed_facets: &BTreeSet<String>,
) -> Option<(String, String)> {
    if !hook
        .watch
        .iter()
        .any(|facet| changed_facets.contains(facet))
    {
        return None;
    }

    let command = resolve_dispatch(&hook.dispatch, selection)?
        .trim()
        .to_string();
    if command.is_empty() {
        return None;
    }

    Some((hook.name.clone(), command))
}

async fn run_hook(label: String, command: String) -> HookResult {
    match Command::new("bash").arg("-lc").arg(&command).output().await {
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
            output: format!("failed to run '{}': {}", command, err),
        },
    }
}
