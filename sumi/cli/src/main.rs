mod cli;
mod compile;
mod core;
mod error;
mod logging;
mod manifest;
mod state;

use std::process::ExitCode;

fn main() -> ExitCode {
    let cli: cli::Cli = clap::Parser::parse();
    logging::init(cli.log_level.into());

    smol::block_on(async move {
        match cli::command::run(cli).await {
            Ok(code) => code,
            Err(err) => {
                log::error!("{err}");
                ExitCode::from(1)
            }
        }
    })
}
