use std::fs;
use std::io::{self, Read};
use std::num::NonZeroUsize;
use std::path::PathBuf;
use std::thread;
use std::time::Instant;

use alejandra::config::{Config, Indentation};
use clap::{Parser, ValueEnum};
use crossbeam_channel as channel;
use rewrite::{format, rewrite};

mod rewrite;

pub type Error = Box<dyn std::error::Error>;

#[derive(Parser)]
struct Args {
    #[arg(long, default_value = "6")]
    max_collapse: NonZeroUsize,

    #[arg(long, value_enum, default_value_t)]
    indentation: IndentationArg,

    #[arg(long)]
    space_around_brackets: bool,

    #[arg(short, long)]
    quiet: bool,

    #[arg(long)]
    no_rewrite: bool,

    #[arg(long)]
    threads: Option<NonZeroUsize>,

    paths: Vec<PathBuf>,
}

#[derive(Clone, Copy, Default, ValueEnum)]
enum IndentationArg {
    FourSpaces,
    Tabs,
    #[default]
    TwoSpaces,
}

impl From<IndentationArg> for Indentation {
    fn from(value: IndentationArg) -> Self {
        match value {
            IndentationArg::FourSpaces => Indentation::FourSpaces,
            IndentationArg::Tabs => Indentation::Tabs,
            IndentationArg::TwoSpaces => Indentation::TwoSpaces,
        }
    }
}

fn run(
    source: &str,
    config: Config,
    max_collapse: usize,
    no_rewrite: bool,
) -> Result<String, Error> {
    if no_rewrite {
        format(source, config)
    } else {
        rewrite(source, max_collapse, config)
    }
}

fn main() {
    let result = || -> Result<(), Error> {
        let args = Args::parse();
        let config = Config {
            indentation: args.indentation.into(),
            space_around_brackets: args.space_around_brackets,
        };
        let max_collapse = args.max_collapse.get();
        let no_rewrite = args.no_rewrite;
        let threads = args
            .threads
            .unwrap_or_else(|| thread::available_parallelism().unwrap_or(NonZeroUsize::MIN))
            .get();
        let mut paths = args.paths;

        if paths.is_empty() {
            let mut source = String::new();
            io::stdin().read_to_string(&mut source)?;
            print!("{}", run(&source, config, max_collapse, no_rewrite)?);
            return Ok(());
        }

        let started = Instant::now();
        let mut files = 0;
        let (jobs_tx, jobs_rx) = channel::bounded::<(PathBuf, String)>(16);
        let formatters: Vec<_> = (0..threads)
            .map(|_| {
                let jobs_rx = jobs_rx.clone();
                thread::spawn(move || {
                    let mut errors = 0;
                    while let Ok((path, before)) = jobs_rx.recv() {
                        match run(&before, config, max_collapse, no_rewrite) {
                            Ok(after) if after != before => {
                                if let Err(error) = fs::write(&path, after) {
                                    errors += 1;
                                    eprintln!("nix-tidy: {}: {error}", path.display());
                                }
                            }
                            Ok(_) => {}
                            Err(error) => {
                                errors += 1;
                                eprintln!("nix-tidy: {}: {error}", path.display());
                            }
                        }
                    }
                    errors
                })
            })
            .collect();

        while let Some(path) = paths.pop() {
            if path.is_dir() {
                for entry in fs::read_dir(path)? {
                    let path = entry?.path();
                    if path.is_dir() {
                        if !matches!(
                            path.file_name().and_then(|name| name.to_str()),
                            Some(".direnv" | ".git" | "target")
                        ) {
                            paths.push(path);
                        }
                    } else if path.extension().is_some_and(|ext| ext == "nix") {
                        paths.push(path);
                    }
                }
                continue;
            }

            files += 1;
            let before = fs::read_to_string(&path)?;
            jobs_tx.send((path, before))?;
        }

        drop(jobs_tx);
        if formatters.into_iter().map(|thread| thread.join().unwrap()).sum::<usize>() > 0 {
            return Err(io::Error::other("formatting failed").into());
        }

        if !args.quiet {
            println!("formatted {files} files in {:?}", started.elapsed());
        }

        Ok(())
    }();

    if let Err(error) = result {
        eprintln!("nix-tidy: {error}");
        std::process::exit(1);
    }
}
