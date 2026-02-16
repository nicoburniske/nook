{inputs, ...}: let
  mkHelixPluginModule = {
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
        patches = (prevAttrs.patches or []) ++ [./patches/bufferline-use-doc-name.patch];
        cargoBuildFeatures = (prevAttrs.cargoBuildFeatures or []) ++ ["steel"];
      });

    hxPlugin = pkgs.writeShellScriptBin "hx-plugin" ''
      set -eu

      export HELIX_STEEL_CONFIG="${config.lib.sumi.paths.config}/helix-plugin/plugins"

      exec "${helixSteelPackage}/bin/hx" \
        -c "${config.lib.sumi.paths.config}/helix-plugin/config.toml" \
        "$@"
    '';
  in {
    environment.systemPackages = [
      hxPlugin
      pkgs.nil
      pkgs.nixd
    ];

    sumi.file = {
      "helix-plugin/config.toml" = {
        dependsOn = ["theme"];
        render = ctx: let
          theme = ctx.values.theme;
        in
          tomlFormat.generate "sumi-helix-plugin-config-${ctx.selection.theme}.toml" {
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

      "helix-plugin/languages.toml".source = tomlFormat.generate "sumi-helix-plugin-languages.toml" {
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

      "helix-plugin/plugins".source = config.lib.sumi.mkOutOfStoreSymlink "${config.lib.sumi.paths.flakeRootOrErr}/modules/helix-plugin/plugins";
    };

    sumi.program.helixPlugin.reload =
      if pkgs.stdenv.isDarwin
      then "/usr/bin/pkill -USR1 hx || true"
      else "${pkgs.procps}/bin/pkill -USR1 hx || true";
  };
in {
  flake.modules.nixos.helixPlugin = mkHelixPluginModule;
  flake.modules.darwin.helixPlugin = mkHelixPluginModule;
}
