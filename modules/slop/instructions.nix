{
  instructions = ''
    - strive for simplicity
    - no helper fns unless needed to actually deduplicate NON-trivial code
      - if a fn is only called once, it should not be a helper fn
      - if a fn must exist, and is called once (e.g. recursion), declare it locally to the fn body
    - code is organized MOST to LEAST important from TOP to BOTTOM
    - comments do not contain uppercase UNLESS it's for something formal like a type name
    - comments should be minimal. no semicolons or hyphens. try and match the density of nearby comments.
    - rust code should not have any intermediary allocations (e.g. collecting all map keys into a vec for no reason) unless absolutely necessary
    - avoid test bloat. temporary implementation tests are fine, but only critical behavior and regression tests should remain
    - use nushell for scripting. use `nix shell` for missing tools. no python or perl
    - never install or configure tools globally. use nix shells and workspace-local state
    - prefer visibility on rust modules over their members. within a private module, members should be pub or private
  '';

  allowedCommands = [
    "cargo build"
    "cargo check"
    "cargo clippy"
    "cargo fmt"
    "cargo test"
    "cat"
    "diff"
    "fd"
    "file"
    "git add"
    "git branch"
    "git cherry-pick"
    "git commit"
    "git diff"
    "git fetch"
    "git lfs fetch"
    "git lfs pull"
    "git log"
    "git merge"
    "git mv"
    "git pull"
    "git rebase"
    "git remote"
    "git restore --staged"
    "git rev-parse"
    "git revert"
    "git show"
    "git stash apply"
    "git stash pop"
    "git stash push"
    "git status"
    "git submodule sync"
    "git submodule update"
    "git switch"
    "git tag"
    "git worktree add"
    "head"
    "ls"
    "nix develop"
    "nix eval"
    "nix flake check"
    "nix flake metadata"
    "nix flake show"
    "nix-instantiate"
    "pwd"
    "readlink"
    "realpath"
    "rg"
    "stat"
    "tail"
    "tree"
    "wc"
    "which"
  ];

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
