use crate::dispatch::{CompiledDispatch, Dispatch};
use crate::error::AppError;
use crate::manifest::{FacetDef, Manifest, ManifestFile, ManifestHook, Selection};
use std::collections::{BTreeMap, BTreeSet};
use std::path::PathBuf;

#[derive(Debug, Clone)]
pub struct CompiledManifest {
    pub home: PathBuf,
    pub facets: BTreeMap<String, FacetDef>,
    pub default_selection: Selection,
    pub files: Vec<CompiledFile>,
    pub hooks: Vec<CompiledHook>,
}

#[derive(Debug, Clone)]
pub struct CompiledFile {
    pub path: String,
    pub dispatch: CompiledDispatch<PathBuf>,
}

#[derive(Debug, Clone)]
pub struct CompiledHook {
    pub name: String,
    pub watch: Vec<String>,
    pub dispatch: CompiledDispatch<String>,
}

pub fn compile_manifest(manifest: Manifest) -> Result<CompiledManifest, AppError> {
    if manifest.version != 2 {
        return Err(AppError::InvalidManifest {
            message: format!(
                "unsupported manifest version '{}', expected 2",
                manifest.version
            ),
        });
    }

    validate_facets(&manifest.facets)?;
    let default_selection =
        compile_default_selection(&manifest.facets, &manifest.default_selection)?;

    let mut files = Vec::with_capacity(manifest.files.len());
    let mut seen_paths = BTreeSet::new();
    for file in manifest.files {
        if !seen_paths.insert(file.path.clone()) {
            return Err(AppError::DuplicatePath { path: file.path });
        }
        files.push(compile_file(file, &manifest.facets)?);
    }

    let mut hooks = Vec::with_capacity(manifest.hooks.len());
    for hook in manifest.hooks {
        hooks.push(compile_hook(hook, &manifest.facets)?);
    }

    Ok(CompiledManifest {
        home: manifest.home,
        facets: manifest.facets,
        default_selection,
        files,
        hooks,
    })
}

fn validate_facets(facets: &BTreeMap<String, FacetDef>) -> Result<(), AppError> {
    for (facet_name, facet) in facets {
        if facet.variants.is_empty() {
            return Err(AppError::InvalidManifest {
                message: format!("facet '{facet_name}' must define at least one variant"),
            });
        }

        if !facet.variants.contains_key(&facet.default) {
            return Err(AppError::InvalidManifest {
                message: format!(
                    "facet '{facet_name}' default '{}' is missing from variants",
                    facet.default
                ),
            });
        }
    }

    Ok(())
}

fn compile_default_selection(
    facets: &BTreeMap<String, FacetDef>,
    overrides: &Selection,
) -> Result<Selection, AppError> {
    let mut selection = Selection::new();

    for (facet_name, facet) in facets {
        selection.insert(facet_name.clone(), facet.default.clone());
    }

    for (facet_name, value) in overrides {
        let facet = facets
            .get(facet_name)
            .ok_or_else(|| AppError::InvalidManifest {
                message: format!("defaultSelection references unknown facet '{}'", facet_name),
            })?;

        if !facet.variants.contains_key(value) {
            return Err(AppError::InvalidManifest {
                message: format!(
                    "defaultSelection contains invalid value '{}' for facet '{}'",
                    value, facet_name
                ),
            });
        }

        selection.insert(facet_name.clone(), value.clone());
    }

    Ok(selection)
}

fn compile_file(
    file: ManifestFile,
    facets: &BTreeMap<String, FacetDef>,
) -> Result<CompiledFile, AppError> {
    if file.path.is_empty() {
        return Err(AppError::InvalidManifest {
            message: "managed file path must not be empty".to_string(),
        });
    }

    Ok(CompiledFile {
        path: file.path,
        dispatch: compile_dispatch(file.dispatch, facets, "file dispatch")?,
    })
}

fn compile_hook(
    hook: ManifestHook,
    facets: &BTreeMap<String, FacetDef>,
) -> Result<CompiledHook, AppError> {
    if hook.name.trim().is_empty() {
        return Err(AppError::InvalidManifest {
            message: "hook name must not be empty".to_string(),
        });
    }

    validate_watch(&hook.watch, facets, format!("hook '{}'", hook.name))?;

    if let Dispatch::Select {
        facets: dispatch_facets,
        ..
    } = &hook.dispatch
    {
        if dispatch_facets != &hook.watch {
            return Err(AppError::InvalidManifest {
                message: format!(
                    "hook '{}' dispatch facets must exactly match hook watch",
                    hook.name
                ),
            });
        }
    }

    Ok(CompiledHook {
        name: hook.name,
        watch: hook.watch,
        dispatch: compile_dispatch(hook.dispatch, facets, "hook dispatch")?,
    })
}

fn compile_dispatch<T: Clone>(
    dispatch: Dispatch<T>,
    facets: &BTreeMap<String, FacetDef>,
    context: &str,
) -> Result<CompiledDispatch<T>, AppError> {
    match dispatch {
        Dispatch::Static { value } => Ok(CompiledDispatch::Static(value)),
        Dispatch::Select {
            facets: dispatch_facets,
            cases,
        } => {
            validate_watch(&dispatch_facets, facets, context.to_string())?;

            let mut by_tuple = BTreeMap::new();
            for case in cases {
                if case.variants.len() != dispatch_facets.len() {
                    return Err(AppError::InvalidManifest {
                        message: format!(
                            "{context} has case with {} variants but {} watched facets",
                            case.variants.len(),
                            dispatch_facets.len(),
                        ),
                    });
                }

                for (facet_name, variant_name) in dispatch_facets.iter().zip(case.variants.iter()) {
                    let facet = facets.get(facet_name).expect("facet validated above");
                    if !facet.variants.contains_key(variant_name) {
                        return Err(AppError::InvalidManifest {
                            message: format!(
                                "{context} references invalid variant '{}' for facet '{}'",
                                variant_name, facet_name
                            ),
                        });
                    }
                }

                if by_tuple.insert(case.variants.clone(), case.value).is_some() {
                    return Err(AppError::InvalidManifest {
                        message: format!("{context} contains duplicate dispatch tuple"),
                    });
                }
            }

            Ok(CompiledDispatch::Select {
                facets: dispatch_facets,
                by_tuple,
            })
        }
    }
}

fn validate_watch(
    watch: &[String],
    facets: &BTreeMap<String, FacetDef>,
    context: String,
) -> Result<(), AppError> {
    if watch.is_empty() {
        return Err(AppError::InvalidManifest {
            message: format!("{context} must declare at least one watched facet"),
        });
    }

    let mut seen = BTreeSet::new();
    for facet_name in watch {
        if !seen.insert(facet_name) {
            return Err(AppError::InvalidManifest {
                message: format!(
                    "{context} contains duplicate watched facet '{}'",
                    facet_name
                ),
            });
        }

        if !facets.contains_key(facet_name) {
            return Err(AppError::InvalidManifest {
                message: format!("{context} references unknown facet '{}'", facet_name),
            });
        }
    }

    Ok(())
}
