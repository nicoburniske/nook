{ config, lib, pkgs, ... }: {
  programs.git = {
    enable = true;
    userName = "Nico Burniske";
    userEmail = "nicoburniske@gmail.com";

    signing = {
      key = "~/.ssh/id_ed25519.pub";
      signByDefault = true;
    };

    aliases = {
      ca = "commit --amend --no-edit";
    };

    extraConfig = {
      gpg.format = "ssh";
      commit.gpgsign = true;
      push.autoSetupRemote = true;
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
        features = "stylix";

        "stylix" = with config.lib.stylix.colors; {
          "${
            if config.stylix.polarity == "dark"
            then "dark"
            else "light"
          }" =
            true;

          file-style = "#${base05} bold";
          file-decoration-style = "#${base0A} ul";
          file-added-label = "[+]";
          file-copied-label = "[==]";
          file-modified-label = "[*]";
          file-removed-label = "[-]";
          file-renamed-label = "[->]";

          hunk-header-decoration-style = "#${base0D} box ul";
          hunk-header-file-style = "#${base0C}";
          hunk-header-line-number-style = "#${base0A}";
          hunk-header-style = "file line-number syntax";

          line-numbers-left-format = "{nm:>3}┊";
          line-numbers-right-format = "{np:>3}┊";
          line-numbers-left-style = "#${base03}";
          line-numbers-right-style = "#${base03}";
          line-numbers-minus-style = "#${base08} bold";
          line-numbers-plus-style = "#${base0B} bold";
          line-numbers-zero-style = "#${base04}";

          minus-style = "syntax #${base01}";
          minus-emph-style =
            "syntax "
            + (
              if config.stylix.polarity == "dark"
              then "#332222"
              else "#fff5f5"
            );
          plus-style = "syntax #${base01}";
          plus-emph-style =
            "syntax "
            + (
              if config.stylix.polarity == "dark"
              then "#223322"
              else "#f5fff5"
            );

          zero-style = "syntax";
          whitespace-error-style = "#${base08} reverse";

          commit-decoration-style = "#${base0A} box";
          commit-style = "#${base05} bold";

          blame-code-style = "syntax";
          blame-format = "{author:<18} ({commit:>7}) ┊{timestamp:^16}┊ ";
          blame-palette = "#${base00} #${base01} #${base02} #${base03}";
        };
      };
    };
  };
}