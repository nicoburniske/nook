{
  lib,
  pkgs,
  ...
}: {
  programs.helix = {
    enable = true;

    settings = {
      editor = {
        bufferline = "always";
        cursorline = true;
        color-modes = true;
        true-color = true;

        end-of-line-diagnostics = "hint";
        popup-border = "all";

        cursor-shape = {
          insert = "bar";
          select = "underline";
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

        # Launch lazygit in kitty overlay
        "C-g" = ":sh kitty @ launch --type=overlay --cwd=current lazygit >/dev/null";

        # Launch yazi file picker in kitty overlay
        "C-f" = [
          ":sh rm -f /tmp/yazi-pick"
          ":sh kitty @ launch --type=overlay --cwd=current --wait-for-child-to-exit ~/.config/helix/kitty-yazi-picker.sh >/dev/null"
          ":open %sh{cat /tmp/yazi-pick 2>/dev/null || echo %{buffer_name}}"
        ];
        "C-l" = "goto_next_buffer";
        "C-h" = "goto_previous_buffer";
        "C-x" = ":buffer-close";

        space = {
          q = ":quit";
          Q = ":quit!";
          w = ":write";
          W = ":write!";
          l = let
            clipboard =
              if pkgs.stdenv.isDarwin
              then "pbcopy"
              else "wl-copy";
          in ":sh if [ '%{selection_line_start}' != '%{selection_line_end}' ]; then printf '%{buffer_name}:%{selection_line_start}-%{selection_line_end}'; else printf '%{buffer_name}:%{cursor_line}'; fi | ${clipboard}";
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
          formatter = {
            command = "alejandra";
            args = ["-"];
          };
          auto-format = true;
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

  # Kitty yazi picker script for helix integration
  home.file.".config/helix/kitty-yazi-picker.sh" = {
    executable = true;
    text = ''
      #!/usr/bin/env bash
      # Launch yazi and capture selected file to temp file
      yazi --chooser-file=/tmp/yazi-pick
      # Exit overlay when done
      exit 0
    '';
  };

  # No additional packages needed for kitty integration
  # The kitty-yazi-picker.sh script is created via home.file above

  # Export activation hook for helix reload
  home.activation.reloadHelix = let
    pkill =
      if pkgs.stdenv.isDarwin
      then "/usr/bin/pkill"
      else "${pkgs.procps}/bin/pkill";
  in
    lib.hm.dag.entryAfter ["linkGeneration"] ''
      echo "reloading helix config"
      ${pkill} -USR1 hx || true
    '';
}
