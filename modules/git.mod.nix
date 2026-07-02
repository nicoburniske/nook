{...}: {
  flake.mod.common.git = {
    lib,
    pkgs,
    ...
  }: {
    environment.systemPackages = with pkgs; [
      git
      git-lfs
      difftastic
    ];

    sumi.configFile = {
      "git/config".value = lib.generators.toGitINI {
        user = {
          name = "Nico Burniske";
          email = "nicoburniske@gmail.com";
          signingkey = "~/.ssh/id_ed25519.pub";
        };
        commit.gpgsign = true;
        gpg.format = "ssh";
        alias = {
          ca = "commit --amend --no-edit";
          dlog = "log -p --ext-diff";
          dshow = "show --ext-diff";
        };
        push.autoSetupRemote = true;
        pull.rebase = true;
        rerere.enabled = true;
        core = {
          editor = "hx";
        };
        diff.external = "difft";
      };
    };
  };
}
