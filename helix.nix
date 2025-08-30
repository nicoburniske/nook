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

        "C-g" = ":sh zellij run -c -f -n git -x 5%% -y 5%% --width 90%% --height 90%% -- lazygit";
        "C-r" = ":sh zellij run -c -f -n scooter -x 5%% -y 5%% --width 90%% --height 90%% -- scooter";
        "C-f" = ":sh zellij run -c -f -n yazi -x 5%% -y 5%% --width 90%% --height 90%% -- bash ~/.config/helix/yazi-picker.sh open %{buffer_name}";

        space = {
          q = ":quit";
          w = ":write";
          l = ":sh if [ '%{selection_line_start}' != '%{selection_line_end}' ]; then printf '%{buffer_name}:%{selection_line_start}-%{selection_line_end}'; else printf '%{buffer_name}:%{cursor_line}'; fi | wl-copy";
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

  # Helix yazi picker script
  home.file.".config/helix/yazi-picker.sh" = {
    executable = true;
    text = ''
      #!/usr/bin/env bash

      paths=$(yazi "$2" --chooser-file=/dev/stdout | while read -r; do printf "%q " "$REPLY"; done)

      if [[ -n "$paths" ]]; then
        zellij action toggle-floating-panes
        zellij action write 27 # send <Escape> key
        zellij action write-chars ":$1 $paths"
        zellij action write 13 # send <Enter> key
      else
        zellij action toggle-floating-panes
      fi
    '';
  };

  home.packages = with pkgs; [
    # Helix-related shell script for yazi file picking
    (writeShellScriptBin "yz-fp" ''
      #!/usr/bin/env bash
      zellij action toggle-floating-panes
      zellij action write 27 # send escape key
      for selected_file in "$@"
      do
        zellij action write-chars ":open $selected_file"
        zellij action write 13 # send enter key
      done
      zellij action toggle-floating-panes
      zellij action close-pane
    '')
  ];
  
  # Export activation hook for helix reload
  home.activation.reloadHelix = lib.hm.dag.entryAfter ["linkGeneration"] ''
    echo "reloading helix config"
    /usr/bin/pkill -USR1 hx || true
  '';
}
