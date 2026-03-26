pub mod command;

use clap::{Parser, Subcommand};
use std::path::PathBuf;

#[derive(Debug, Parser)]
#[command(name = "sumi", version, about = "facet-based runtime config switching")]
pub struct Cli {
    #[command(subcommand)]
    pub command: Option<Command>,

    #[arg(long, global = true)]
    pub manifest: Option<PathBuf>,

    #[arg(long, global = true, value_enum, default_value_t = LogLevelArg::Warn)]
    pub log_level: LogLevelArg,
}

#[derive(Debug, Subcommand)]
pub enum Command {
    Switch(SwitchArgs),
    Facets(FacetsArgs),
    Selection(SelectionArgs),
    Doctor,
}

#[derive(Debug, Clone, Copy, clap::ValueEnum)]
pub enum LogLevelArg {
    Error,
    Warn,
    Info,
    Debug,
    Trace,
}

impl From<LogLevelArg> for log::LevelFilter {
    fn from(value: LogLevelArg) -> Self {
        match value {
            LogLevelArg::Error => log::LevelFilter::Error,
            LogLevelArg::Warn => log::LevelFilter::Warn,
            LogLevelArg::Info => log::LevelFilter::Info,
            LogLevelArg::Debug => log::LevelFilter::Debug,
            LogLevelArg::Trace => log::LevelFilter::Trace,
        }
    }
}

#[derive(Debug, Clone, clap::Args)]
pub struct SwitchArgs {
    #[arg(value_name = "FACET=VALUE")]
    pub set: Vec<String>,
}

#[derive(Debug, Clone, clap::Args)]
pub struct FacetsArgs {
    pub facet: Option<String>,

    #[arg(long)]
    pub json: bool,
}

#[derive(Debug, Clone, clap::Args)]
pub struct SelectionArgs {
    #[arg(long)]
    pub json: bool,
}
