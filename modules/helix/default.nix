{inputs, ...}: let
  mkHelixModule = {
    config,
    pkgs,
    ...
  }: let
    tomlFormat = pkgs.formats.toml {};
    helixRoot = "${config.lib.sumi.paths.flakeRootOrErr}/modules/helix";

    helixSteelPackage =
      (inputs.helix-steel.packages.${pkgs.stdenv.hostPlatform.system}.default.override {
        includeGrammarIf = grammar: grammar.name != "go-format-string";
      }).overrideAttrs
      (prevAttrs: {
        patches =
          (prevAttrs.patches or [])
          ++ [
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

    sumi.configFile =
      {
        "helix/config.toml" = {
          watch = ["theme"];
          value = ctx: let
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
                  display-inlay-hints = true;
                  display-messages = true;
                  display-progress-messages = true;
                  goto-reference-include-declaration = false;
                };
                inline-diagnostics.cursor-line = "info";
                soft-wrap.enable = true;
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

        "helix/languages.toml".value = tomlFormat.generate "sumi-helix-languages.toml" {
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
            {
              name = "nu";
              formatter = {
                command = "nufmt";
                args = ["--stdin"];
              };
              auto-format = true;
            }
          ];

          language-server = {
            rust-analyzer = {
              command = "rust-analyzer";
              config = {
                checkOnSave.enable = true;
                inlayHints = {
                  chainingHints.enable = true;
                  typeHints.enable = false;
                  parameterHints.enable = false;
                };
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

        "helix/plugins".value = config.lib.sumi.mkOutOfStoreSymlink "${helixRoot}/plugins";
      }
      // builtins.listToAttrs
      (map (name: {
          name = "helix/themes/${name}.toml";
          value.value = config.lib.sumi.mkOutOfStoreSymlink "${helixRoot}/themes/${name}.toml";
        }) [
          "modus"
          "melissa-light"
          "space-age"
          "gruvbox"
          "ashen"
          "cano"
        ]);

    sumi.hook.helix = {
      watch = ["theme"];
      command =
        if pkgs.stdenv.isDarwin
        then "/usr/bin/pkill -USR1 hx || true"
        else "${pkgs.procps}/bin/pkill -USR1 hx || true";
    };
  };
in {
  flake.modules.nixos.helix = mkHelixModule;
  flake.modules.darwin.helix = mkHelixModule;
}
