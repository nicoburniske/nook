{
  lib,
  pkgs,
  config,
  osConfig,
  ...
}: {
  stylix.targets.helix.transparent = true;

  programs.helix = {
    enable = true;

    extraPackages = with pkgs; [nixd nil];

    themes = {
      absolute-heat =
        {
          inherits = config.stylix.override.helix or "stylix";
          # make bg transparent on all themes
          ui.background = {};
        }
        # remove italics from comments
        // lib.optionalAttrs (!config.stylix.override ? helix) {comment = {fg = "base03";};};

      space-age = ./space-age.toml;
      modus = ./modus.toml;
    };

    settings = {
      theme = lib.mkForce "absolute-heat";

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

        "C-g" = ":sh kitty @ launch --type=overlay --cwd=\"$(pwd)\" --window-title=current lazygit >/dev/null";
        "C-f" = ":sh kitty @ launch --type=overlay --cwd=\"$(pwd)\" --window-title=current ~/.config/helix/kitty-yazi-picker.sh %{buffer_name} >/dev/null";
        "C-t" = ":sh kitty @ launch --type=overlay --cwd=\"$(pwd)\" --window-title=current >/dev/null";
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
          language-servers = ["nil" "nixd"];
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
        {
          name = "toml";
          language-servers = ["taplo"];
          formatter = {
            command = "taplo";
            args = ["fmt" "-"];
          };
          auto-format = true;
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

        nixd = {
          command = "nixd";
          args = ["--semantic-tokens=true"];
          config.nixd = let
            flakePath = "${config.home.homeDirectory}/nook";
            myFlake = ''(builtins.getFlake "${flakePath}")'';
            isNixOS = pkgs.stdenv.isLinux;
            hostName =
              if isNixOS
              then osConfig.networking.hostName
              else osConfig.networking.computerName;
            configType =
              if isNixOS
              then "nixosConfigurations"
              else "darwinConfigurations";
            systemOpts = "${myFlake}.${configType}.${hostName}.options";
          in {
            nixpkgs.expr = "import ${myFlake}.inputs.nixpkgs { }";
            options =
              if isNixOS
              then {
                nixos.expr = systemOpts;
                home-manager.expr = "${systemOpts}.home-manager.users.type.getSubOptions []";
              }
              else {
                darwin.expr = systemOpts;
                home-manager.expr = "${systemOpts}.home-manager.users.type.getSubOptions []";
              };
          };
        };

        dart = {
          command = "dart";
        };
      };
    };
  };

  home.file.".config/helix/kitty-yazi-picker.sh" = {
    executable = true;
    text = ''
      #!/usr/bin/env bash
      # Launch yazi picker
      # $1 = buffer_name (file path)

      if [ -n "$1" ]; then
        paths=$(${pkgs.yazi}/bin/yazi "$1" --chooser-file=/dev/stdout | while read -r; do printf "%q " "$REPLY"; done)
      else
        paths=$(${pkgs.yazi}/bin/yazi --chooser-file=/dev/stdout | while read -r; do printf "%q " "$REPLY"; done)
      fi

      # If files were selected, send commands back to Helix
      if [[ -n "$paths" ]]; then
        kitty @ send-text --match 'state:overlay_parent' '\x1b'
        kitty @ send-text --match 'state:overlay_parent' ":open $paths"
        kitty @ send-text --match 'state:overlay_parent' '\r'
      fi
    '';
  };

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
