{
  lib,
  pkgs,
  config,
  osConfig,
  ...
}: let
  clipboard =
    if pkgs.stdenv.isDarwin
    then "pbcopy"
    else "wl-copy";

  copyLineRef = pkgs.writeShellScriptBin "hx-copy-line-reference" ''
    buffer_name="$1"
    cursor_line="$2"
    selection_line_start="$3"
    selection_line_end="$4"

    if [ "$selection_line_start" != "$selection_line_end" ]; then
      printf "%s:%s-%s" "$buffer_name" "$selection_line_start" "$selection_line_end" | ${clipboard}
    else
      printf "%s:%s" "$buffer_name" "$cursor_line" | ${clipboard}
    fi
  '';

  copyLineUrl = pkgs.writeShellScriptBin "hx-copy-line-url" ''
    buffer_name="$1"
    cursor_line="$2"
    selection_line_start="$3"
    selection_line_end="$4"

    url=$(git remote get-url origin 2>/dev/null)

    if [ -z "$url" ]; then
      return 1
    fi

    url=''${url#git@}
    url=''${url/:/\/}
    url=''${url%.git}
    url="https://''$url"

    branch=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "HEAD")

    if [ "$selection_line_start" != "$selection_line_end" ]; then

      printf "%s/blob/%s/%s#L%s-L%s" "$url" "$branch" "$buffer_name" "$selection_line_start" "$selection_line_end" | ${clipboard}
    else
      printf "%s/blob/%s/%s#L%s" "$url" "$branch" "$buffer_name" "$cursor_line" | ${clipboard}
    fi
  '';

  yaziPicker = pkgs.writeShellScriptBin "hx-yazi-picker" ''
    buffer_name="$1"

    if [ -n "$buffer_name" ]; then
      paths=$(${pkgs.yazi}/bin/yazi "$buffer_name" --chooser-file=/dev/stdout | while read -r; do printf "%q " "$REPLY"; done)
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
in {
  stylix.targets.helix.transparent = lib.mkForce true;

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

      keys = let
        common = {
          X = "extend_line_above";
          space = {
            q = ":quit";
            Q = ":quit!";
            w = ":write";
            W = ":write!";
            x = ":bc!";
            l = ":sh ${copyLineRef}/bin/hx-copy-line-reference %{buffer_name} %{cursor_line} %{selection_line_start} %{selection_line_end}";
            o = ":sh ${copyLineUrl}/bin/hx-copy-line-url %{buffer_name} %{cursor_line} %{selection_line_start} %{selection_line_end}";
            "C-r" = ":rla";
          };
        };
      in {
        normal =
          {
            "C-g" = ":sh kitty @ launch --type=overlay --cwd=\"$(pwd)\" --window-title=current lazygit >/dev/null";
            "C-f" = ":sh kitty @ launch --type=overlay --cwd=\"$(pwd)\" --window-title=current ${yaziPicker}/bin/hx-yazi-picker %{buffer_name} >/dev/null";
            "C-t" = ":sh kitty @ launch --type=overlay --cwd=\"$(pwd)\" --window-title=current >/dev/null";
            "C-l" = "goto_next_buffer";
            "C-h" = "goto_previous_buffer";
            "C-x" = ":buffer-close";
          }
          // common;

        select =
          {
          }
          // common;
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
            flakePath = config.nook.paths.flakeRoot;
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
