mod cli;
mod engine;
mod error;
mod logging;
mod manifest;
mod snapshot;

use clap::Parser;
use cli::{Cli, Command};
use engine::{ConflictPolicy, Engine};
use log::error;
use std::process::ExitCode;

fn main() -> ExitCode {
    let cli = Cli::parse();
    logging::init(cli.verbose);

    match run(cli) {
        Ok(code) => code,
        Err(err) => {
            error!("{err}");
            ExitCode::from(1)
        }
    }
}

fn run(cli: Cli) -> Result<ExitCode, error::AppError> {
    match cli.command {
        Command::Apply(args) => {
            let manifest = manifest::Manifest::load(&args.manifest)?;
            let engine = Engine {
                conflict_policy: ConflictPolicy::from(args.conflict_policy),
            };

            let summary = engine.apply(manifest, &args.state_dir, &args.theme)?;
            println!(
                "created={} updated={} removed={} unchanged={} failed={}",
                summary.created,
                summary.updated,
                summary.removed,
                summary.unchanged,
                summary.failed
            );

            Ok(if summary.failed > 0 {
                ExitCode::from(2)
            } else {
                ExitCode::SUCCESS
            })
        }
    }
}
