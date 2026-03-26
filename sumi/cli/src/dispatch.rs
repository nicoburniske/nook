use crate::manifest::Selection;
use serde::Deserialize;
use std::collections::BTreeMap;

#[derive(Debug, Clone, Deserialize)]
#[serde(tag = "kind", rename_all = "lowercase", deny_unknown_fields)]
pub enum Dispatch<T> {
    Static {
        value: T,
    },
    Select {
        facets: Vec<String>,
        cases: Vec<DispatchCase<T>>,
    },
}

#[derive(Debug, Clone, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct DispatchCase<T> {
    pub variants: Vec<String>,
    pub value: T,
}

#[derive(Debug, Clone)]
pub enum CompiledDispatch<T> {
    Static(T),
    Select {
        facets: Vec<String>,
        by_tuple: BTreeMap<Vec<String>, T>,
    },
}

pub fn resolve_dispatch<'a, T>(
    dispatch: &'a CompiledDispatch<T>,
    selection: &Selection,
) -> Option<&'a T> {
    match dispatch {
        CompiledDispatch::Static(value) => Some(value),
        CompiledDispatch::Select { facets, by_tuple } => {
            let mut tuple = Vec::with_capacity(facets.len());
            for facet in facets {
                let variant = selection.get(facet)?;
                tuple.push(variant.clone());
            }
            by_tuple.get(&tuple)
        }
    }
}
