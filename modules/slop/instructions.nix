{
  instructions = ''
    - strive for simplicity
    - no helper fns unless needed to actually deduplicate NON-trivial code
      - if a fn is only called once, it should not be a helper fn
      - if a fn must exist, and is called once (e.g. recursion), declare it locally to the fn body
    - code is organized MOST to LEAST important from TOP to BOTTOM
    - comments do not contain uppercase UNLESS it's for something formal like a type name
    - comments should be minimal
    - rust code should not have any intermediary allocations (e.g. collecting all map keys into a vec for no reason) unless absolutely necessary
    - use nushell for scripting. use `nix shell` for missing tools. no python or perl
    - never install or configure tools globally. use nix shells and workspace-local state
    - prefer visibility on rust modules over their members. within a private module, members should be pub or private
  '';

  forbiddenCommands = [
    "cargo install"
    "nix profile"
    "nix-channel"
    "nix-env"
    "rustup"

    "find /nix/store"
    "find /nix/store/"
    "du /nix/store"
    "du /nix/store/"

    "gh pr close"
    "gh pr merge"
    "gh pr review"
    "gh release delete"
    "gh repo delete"
    "gh run cancel"
    "gh workflow run"
  ];
}
