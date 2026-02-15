use clap::{Parser, ValueEnum};
use std::path::PathBuf;

#[derive(Debug, Parser)]
#[command(name = "sumi-link", version, about = "Sumi manifest apply engine")]
pub struct Cli {
    #[command(subcommand)]
    pub command: Command,

    #[arg(short, long, action = clap::ArgAction::Count, global = true)]
    pub verbose: u8,
}

#[derive(Debug, clap::Subcommand)]
pub enum Command {
    Apply(ApplyArgs),
}

#[derive(Debug, Parser)]
pub struct ApplyArgs {
    #[arg(long)]
    pub manifest: PathBuf,

    #[arg(long)]
    pub state_dir: PathBuf,

    #[arg(long = "set", value_name = "FACET=VALUE")]
    pub set: Vec<String>,

    #[arg(long, value_enum, default_value_t = ConflictPolicyArg::Backup)]
    pub conflict_policy: ConflictPolicyArg,
}

#[derive(Clone, Copy, Debug, Eq, PartialEq, ValueEnum)]
pub enum ConflictPolicyArg {
    Backup,
    Replace,
}
