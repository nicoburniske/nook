use crate::cli::{Cli, Command, FacetsArgs, SelectionArgs, SwitchArgs};
use crate::compile::CompiledManifest;
use crate::core::{
    self, apply, doctor, get_selection, parse_selection_overrides, run_reload_hooks,
    validate_selection_overrides, write_selection, ConflictPolicy,
};
use crate::error::AppError;
use crate::manifest::{FacetDef, Selection};
use serde_json::{json, Map, Value};
use std::collections::BTreeMap;
use std::env;
use std::path::{Path, PathBuf};
use std::process::ExitCode;

struct RuntimeContext {
    manifest: CompiledManifest,
    home_dir: PathBuf,
    state_dir: PathBuf,
}

pub async fn run(cli: Cli) -> Result<ExitCode, AppError> {
    match cli.command {
        Some(Command::Switch(args)) => run_switch(cli.manifest.as_deref(), args).await,
        Some(Command::Facets(args)) => run_facets(cli.manifest.as_deref(), args).await,
        Some(Command::Selection(args)) => run_selection(cli.manifest.as_deref(), args).await,
        Some(Command::Doctor) => run_doctor(cli.manifest.as_deref()).await,
        None => {
            print_usage();
            Ok(ExitCode::SUCCESS)
        }
    }
}

async fn run_switch(
    global_manifest: Option<&Path>,
    args: SwitchArgs,
) -> Result<ExitCode, AppError> {
    let ctx = require_context(global_manifest, None).await?;

    smol::fs::create_dir_all(&ctx.state_dir)
        .await
        .map_err(|source| AppError::CreateDir {
            path: ctx.state_dir.clone(),
            source,
        })?;

    let current = get_selection(&ctx.manifest, &ctx.state_dir).await?;
    let overrides = parse_selection_overrides(&args.set)?;
    validate_selection_overrides(&ctx.manifest, &overrides)?;

    let mut merged = current.clone();
    for (key, value) in overrides {
        merged.insert(key, value);
    }

    let selection = merged;
    let conflict_policy = conflict_policy_from_env()?;

    println!("Linking selection files...");

    let _lock = core::acquire_switch_lock(&ctx.state_dir).await?;
    let summary = apply(
        &ctx.manifest,
        &ctx.home_dir,
        &ctx.state_dir,
        &selection,
        conflict_policy,
    )
    .await?;

    print_apply_summary(&summary);
    if summary.failed > 0 {
        eprintln!("sumi: apply completed with partial failures");
        return Ok(ExitCode::from(2));
    }

    let hook_facets = ctx.manifest.facets.keys().cloned().collect();
    let hook_results = run_reload_hooks(&ctx.manifest, &selection, &hook_facets).await;

    for result in &hook_results {
        if result.ok {
            println!("ok {}", result.label);
        } else {
            eprintln!("warn {}", result.label);
            if !result.output.trim().is_empty() {
                eprintln!("{}", result.output.trim());
            }
        }
    }

    let failed_hooks = hook_results.iter().filter(|result| !result.ok).count();
    if failed_hooks > 0 {
        let labels = hook_results
            .iter()
            .filter(|result| !result.ok)
            .map(|result| result.label.clone())
            .collect::<Vec<_>>()
            .join(", ");
        eprintln!("Hook warnings ({failed_hooks}): {labels}");
    }

    write_selection(&ctx.state_dir, &selection).await?;
    println!("Switched selection");

    Ok(ExitCode::SUCCESS)
}

async fn run_facets(
    global_manifest: Option<&Path>,
    args: FacetsArgs,
) -> Result<ExitCode, AppError> {
    let ctx = require_context(global_manifest, None).await?;
    let selection = get_selection(&ctx.manifest, &ctx.state_dir).await?;

    if let Some(requested_facet) = args.facet {
        let facet =
            ctx.manifest
                .facets
                .get(&requested_facet)
                .ok_or_else(|| AppError::UnknownFacet {
                    facet: requested_facet.clone(),
                })?;

        if args.json {
            let json = facet_json(&requested_facet, facet, &selection);
            println!("{}", serde_json::to_string_pretty(&json).unwrap());
        } else {
            for variant in facet.variants.keys() {
                let prefix = if selection.get(&requested_facet) == Some(variant) {
                    "*"
                } else {
                    " "
                };
                println!("{prefix} {variant}");
            }
        }
        return Ok(ExitCode::SUCCESS);
    }

    if args.json {
        let json = facets_json(&ctx.manifest.facets, &selection);
        println!("{}", serde_json::to_string_pretty(&json).unwrap());
    } else {
        for (facet_name, facet) in &ctx.manifest.facets {
            let current = selection
                .get(facet_name)
                .map(String::as_str)
                .unwrap_or(facet.default.as_str());
            println!(
                "{} current={} default={} variants={}",
                facet_name,
                current,
                facet.default,
                facet.variants.len()
            );
        }
    }

    Ok(ExitCode::SUCCESS)
}

async fn run_selection(
    global_manifest: Option<&Path>,
    args: SelectionArgs,
) -> Result<ExitCode, AppError> {
    let ctx = require_context(global_manifest, None).await?;
    let selection = get_selection(&ctx.manifest, &ctx.state_dir).await?;

    if args.json {
        println!(
            "{}",
            serde_json::to_string_pretty(&selection).map_err(AppError::SerializeJson)?
        );
    } else {
        for (key, value) in selection {
            println!("{key}={value}");
        }
    }

    Ok(ExitCode::SUCCESS)
}

async fn run_doctor(global_manifest: Option<&Path>) -> Result<ExitCode, AppError> {
    let ctx = require_context(global_manifest, None).await?;
    let selection = get_selection(&ctx.manifest, &ctx.state_dir).await?;
    let report = doctor(&ctx.manifest, &ctx.home_dir, &selection).await;

    if report.failures.is_empty() {
        println!("sumi doctor: ok");
        return Ok(ExitCode::SUCCESS);
    }

    for failure in report.failures {
        eprintln!("{failure}");
    }

    Ok(ExitCode::from(1))
}

async fn require_context(
    manifest_override: Option<&Path>,
    state_dir_override: Option<PathBuf>,
) -> Result<RuntimeContext, AppError> {
    let manifest_path = match manifest_override {
        Some(path) => path.to_path_buf(),
        None => {
            let value = env::var("SUMI_MANIFEST").unwrap_or_default();
            if value.is_empty() {
                return Err(AppError::ManifestNotConfigured);
            }
            PathBuf::from(value)
        }
    };

    if smol::fs::metadata(&manifest_path).await.is_err() {
        return Err(AppError::ManifestMissing {
            path: manifest_path,
        });
    }

    let manifest = core::load_manifest(&manifest_path).await?;

    let home_dir = resolve_home_dir(&manifest)?;
    let state_dir = match state_dir_override {
        Some(path) => path,
        None => {
            let env_state = env::var("SUMI_STATE_DIR").unwrap_or_default();
            if !env_state.is_empty() {
                PathBuf::from(env_state)
            } else {
                home_dir.join(".local/state/sumi")
            }
        }
    };

    Ok(RuntimeContext {
        manifest,
        home_dir,
        state_dir,
    })
}

fn resolve_home_dir(manifest: &CompiledManifest) -> Result<PathBuf, AppError> {
    let env_home = env::var("SUMI_HOME_DIR").unwrap_or_default();
    let resolved = if !env_home.is_empty() {
        PathBuf::from(env_home)
    } else if !manifest.home.as_os_str().is_empty() {
        manifest.home.clone()
    } else {
        let home = env::var("HOME").unwrap_or_default();
        if home.is_empty() {
            return Err(AppError::ResolveHomeDirectory);
        }
        PathBuf::from(home)
    };

    if !resolved.is_absolute() {
        return Err(AppError::InvalidHome {
            home: resolved.to_string_lossy().into_owned(),
        });
    }

    Ok(resolved)
}

fn conflict_policy_from_env() -> Result<ConflictPolicy, AppError> {
    let value = env::var("SUMI_CONFLICT_POLICY").unwrap_or_else(|_| "backup".to_string());
    match value.as_str() {
        "backup" => Ok(ConflictPolicy::Backup),
        "replace" => Ok(ConflictPolicy::Replace),
        _ => Err(AppError::InvalidConflictPolicy { value }),
    }
}

fn print_apply_summary(summary: &core::ApplySummary) {
    println!(
        "created={} updated={} removed={} unchanged={} failed={}",
        summary.created, summary.updated, summary.removed, summary.unchanged, summary.failed
    );
}

fn facets_json(facets: &BTreeMap<String, FacetDef>, selection: &Selection) -> Value {
    Value::Object(
        facets
            .iter()
            .map(|(facet_name, facet)| {
                (facet_name.clone(), facet_json(facet_name, facet, selection))
            })
            .collect::<Map<String, Value>>(),
    )
}

fn facet_json(facet_name: &str, facet: &FacetDef, selection: &Selection) -> Value {
    let current = selection
        .get(facet_name)
        .cloned()
        .unwrap_or_else(|| facet.default.clone());
    let variants = facet.variants.keys().cloned().collect::<Vec<_>>();
    json!({
        "current": current,
        "default": facet.default,
        "variants": variants,
    })
}

fn print_usage() {
    println!("sumi - facet-based runtime config switching");
    println!();
    println!("Usage:");
    println!("  sumi [--manifest PATH] facets [facet] [--json]");
    println!("  sumi [--manifest PATH] selection [--json]");
    println!("  sumi [--manifest PATH] switch [facet=value]...");
    println!("  sumi [--manifest PATH] doctor");
}
