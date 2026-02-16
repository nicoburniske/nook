{inputs, ...}: let
  mkHelixModule = {
    config,
    pkgs,
    ...
  }: let
    tomlFormat = pkgs.formats.toml {};

    helixSteelPackage =
      (inputs.helix-steel.packages.${pkgs.stdenv.hostPlatform.system}.default.override {
        includeGrammarIf = grammar: grammar.name != "go-format-string";
      }).overrideAttrs
      (prevAttrs: {
        patches =
          (prevAttrs.patches or [])
          ++ [
            ./patches/hide-bufferline-entries.patch
            ./patches/search-in-directory.patch
          ];
        cargoBuildFeatures = (prevAttrs.cargoBuildFeatures or []) ++ ["steel"];
      });

    hx = pkgs.writeShellScriptBin "hx" ''
      set -eu
      export HELIX_STEEL_CONFIG="${config.lib.sumi.paths.config}/helix/plugins"
      exec "${helixSteelPackage}/bin/hx" "$@"
    '';
  in {
    environment.systemPackages = [
      hx
      pkgs.nil
      pkgs.nixd
    ];

    sumi.file = {
      "helix/config.toml" = {
        dependsOn = ["theme"];
        render = ctx: let
          theme = ctx.values.theme;
        in
          tomlFormat.generate "sumi-helix-config-${ctx.selection.theme}.toml" {
            theme = theme.meta.helix or ctx.selection.theme;

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
              file-picker.hidden = false;
              lsp = {
                display-messages = true;
                goto-reference-include-declaration = false;
              };
              inline-diagnostics.cursor-line = "info";
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
                  "C-r" = ":rla";
                };
              };
            in {
              normal =
                common
                // {
                  "C-l" = "goto_next_buffer";
                  "C-h" = "goto_previous_buffer";
                  "C-x" = ":buffer-close";
                };
              select = common;
            };
          };
      };

      "helix/languages.toml".source = tomlFormat.generate "sumi-helix-languages.toml" {
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
            language-servers = [
              "nil"
              "nixd"
            ];
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
              args = [
                "fmt"
                "-"
              ];
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
          };

          dart.command = "dart";
        };
      };

      "helix/plugins".source = config.lib.sumi.mkOutOfStoreSymlink "${config.lib.sumi.paths.flakeRootOrErr}/modules/helix/plugins";

      "helix/themes/modus.toml".source = ./themes/modus.toml;
      "helix/themes/melissa-light.toml".source = ./themes/melissa-light.toml;
      "helix/themes/space-age.toml".source = ./themes/space-age.toml;
      "helix/themes/gruvbox.toml".source = ./themes/gruvbox.toml;
    };

    sumi.program.helix.reload =
      if pkgs.stdenv.isDarwin
      then "/usr/bin/pkill -USR1 hx || true"
      else "${pkgs.procps}/bin/pkill -USR1 hx || true";
  };
in {
  flake.modules.nixos.helix = mkHelixModule;
  flake.modules.darwin.helix = mkHelixModule;
}
