use crate::error::AppError;
use crate::manifest::{
    FacetDef, FileSource, HookCommand, Manifest, ManifestFile, ManifestHook, Selection,
};
use std::collections::{BTreeMap, BTreeSet};
use std::path::PathBuf;

#[derive(Debug, Clone)]
pub struct CompiledManifest {
    pub home: PathBuf,
    pub facets: BTreeMap<String, FacetDef>,
    pub default_selection: Selection,
    pub variant_roots: BTreeMap<String, BTreeMap<String, PathBuf>>,
    pub files: Vec<CompiledFile>,
    pub hooks: Vec<CompiledHook>,
}

#[derive(Debug, Clone)]
pub struct CompiledFile {
    pub path: String,
    pub source: FileSource,
}

#[derive(Debug, Clone)]
pub struct CompiledHook {
    pub name: String,
    pub watch: String,
    pub command: HookCommand,
}

pub fn compile_manifest(manifest: Manifest) -> Result<CompiledManifest, AppError> {
    if manifest.version != 3 {
        return Err(AppError::InvalidManifest {
            message: format!(
                "unsupported manifest version '{}', expected 3",
                manifest.version
            ),
        });
    }

    validate_facets(&manifest.facets)?;
    let default_selection =
        compile_default_selection(&manifest.facets, &manifest.default_selection)?;
    validate_variant_roots(&manifest.facets, &manifest.variant_roots)?;

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
        variant_roots: manifest.variant_roots,
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

fn validate_variant_roots(
    facets: &BTreeMap<String, FacetDef>,
    roots: &BTreeMap<String, BTreeMap<String, PathBuf>>,
) -> Result<(), AppError> {
    for (facet_name, variants) in roots {
        let facet = facets
            .get(facet_name)
            .ok_or_else(|| AppError::InvalidManifest {
                message: format!("variantRoots references unknown facet '{}'", facet_name),
            })?;

        for variant_name in variants.keys() {
            if !facet.variants.contains_key(variant_name) {
                return Err(AppError::InvalidManifest {
                    message: format!(
                        "variantRoots references invalid variant '{}' for facet '{}'",
                        variant_name, facet_name
                    ),
                });
            }
        }

        for variant_name in facet.variants.keys() {
            if !variants.contains_key(variant_name) {
                return Err(AppError::InvalidManifest {
                    message: format!(
                        "variantRoots is missing variant '{}' for facet '{}'",
                        variant_name, facet_name
                    ),
                });
            }
        }
    }

    Ok(())
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

    validate_file_source(&file.source, facets)?;

    Ok(CompiledFile {
        path: file.path,
        source: file.source,
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

    validate_facet(&hook.watch, facets, format!("hook '{}'", hook.name))?;

    if let HookCommand::Facet { facet, variants } = &hook.command {
        if facet != &hook.watch {
            return Err(AppError::InvalidManifest {
                message: format!("hook '{}' command facet must match hook watch", hook.name),
            });
        }

        validate_variant_map(facet, variants, facets, format!("hook '{}'", hook.name))?;
    }

    Ok(CompiledHook {
        name: hook.name,
        watch: hook.watch,
        command: hook.command,
    })
}

fn validate_file_source(
    source: &FileSource,
    facets: &BTreeMap<String, FacetDef>,
) -> Result<(), AppError> {
    match source {
        FileSource::Static { .. } => Ok(()),
        FileSource::Facet { facet } => validate_facet(facet, facets, "file source".to_string()),
    }
}

fn validate_variant_map(
    facet_name: &str,
    variants: &BTreeMap<String, String>,
    facets: &BTreeMap<String, FacetDef>,
    context: String,
) -> Result<(), AppError> {
    validate_facet(facet_name, facets, context.clone())?;
    let facet = facets.get(facet_name).expect("facet validated above");

    for variant_name in variants.keys() {
        if !facet.variants.contains_key(variant_name) {
            return Err(AppError::InvalidManifest {
                message: format!(
                    "{context} references invalid variant '{}' for facet '{}'",
                    variant_name, facet_name
                ),
            });
        }
    }

    Ok(())
}

fn validate_facet(
    facet_name: &str,
    facets: &BTreeMap<String, FacetDef>,
    context: String,
) -> Result<(), AppError> {
    if facet_name.trim().is_empty() {
        return Err(AppError::InvalidManifest {
            message: format!("{context} must declare a watched facet"),
        });
    }

    if !facets.contains_key(facet_name) {
        return Err(AppError::InvalidManifest {
            message: format!("{context} references unknown facet '{}'", facet_name),
        });
    }

    Ok(())
}
