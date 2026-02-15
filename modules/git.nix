{...}: let
  gitModule = {
    lib,
    pkgs,
    ...
  }: {
    environment.systemPackages = with pkgs; [
      git
      delta
    ];

    sumi.file = {
      ".gitconfig".text = lib.generators.toGitINI {
        user = {
          name = "Nico Burniske";
          email = "nicoburniske@gmail.com";
          signingkey = "~/.ssh/id_ed25519.pub";
        };
        commit.gpgsign = true;
        gpg.format = "ssh";
        alias.ca = "commit --amend --no-edit";
        push.autoSetupRemote = true;
        pull.rebase = true;
        rerere.enabled = true;
        core = {
          pager = "delta";
          editor = "hx";
        };
        url = {
          "git@github.com:" = {
            insteadOf = "https://github.com/";
          };
          "https://github.com/rust-lang/crates.io-index" = {
            insteadOf = "https://github.com/rust-lang/crates.io-index";
          };
        };
        delta = {
          navigate = true;
          side-by-side = true;
          line-numbers = true;
          hyperlinks = true;
        };
      };
    };
  };
in {
  flake.modules.nixos.git = gitModule;
  flake.modules.darwin.git = gitModule;
}
