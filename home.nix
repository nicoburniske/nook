{ config, pkgs, lib, ... }:

{
  # Home Manager needs a bit of information about you and the paths it should manage.
  home.username = "nico";
  home.homeDirectory = "/home/nico";

  # This value determines the Home Manager release that your configuration is
  # compatible with. This helps avoid breakage when a new Home Manager release
  # introduces backwards incompatible changes.
  home.stateVersion = "24.05";

  # Let Home Manager install and manage itself.
  programs.home-manager.enable = true;

  # Zoxide shell integration (fixing the z command issue)
  programs.zoxide = {
    enable = true;
    enableBashIntegration = true;
  };

  # Basic git configuration (simplified from macOS config)
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
      delta = {
        navigate = true;
        side-by-side = true;
        line-numbers = true;
        hyperlinks = true;
      };
    };
  };

  # Basic helix configuration (simplified from macOS config)
  programs.helix = {
    enable = true;

    settings = {
      editor = {
        bufferline = "always";
        cursorline = true;
        color-modes = true;
        end-of-line-diagnostics = "hint";
        popup-border = "all";

        cursor-shape = {
          insert = "bar";
        };

        file-picker = {
          hidden = false;
        };

        lsp = {
          display-messages = true;
          goto-reference-include-declaration = false;
        };

        inline-diagnostics = {
          cursor-line = "info";
        };
      };

      keys.normal = {
        X = "extend_line_above";

        space = {
          q = ":quit";
          w = ":write";
        };
      };

      keys.select = {
        X = "extend_line_above";
      };
    };

    languages = {
      language = [
        {
          name = "rust";
          language-servers = ["rust-analyzer"];
        }
        {
          name = "markdown";
          language-servers = ["marksman"];
        }
        {
          name = "nix";
          language-servers = ["nil"];
        }
        {
          name = "dart";
          language-servers = ["dart"];
        }
      ];

      language-server = {
        rust-analyzer = {
          command = "rust-analyzer";
          config = {
            checkOnSave.enable = true;
            procMacro.enable = true;
          };
        };

        nil = {
          command = "nil";
        };

        dart = {
          command = "dart";
        };
      };
    };
  };

  # Basic packages that were in your macOS home config
  home.packages = with pkgs; [
    ripgrep
    fzf
    lazygit
    delta
    btop
    tokei
    just
    rust-analyzer
    nil
    marksman
  ];
}