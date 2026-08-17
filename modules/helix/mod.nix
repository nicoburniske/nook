{inputs, ...}: {
  inputs.helix-steel = {
    url = "github:mattwparas/helix/steel-event-system";
    inputs.nixpkgs.follows = "nixpkgs";
  };

  homeModules.helix = {
    config,
    host,
    lib,
    pkgs,
    ...
  }: let
    mkOutOfStoreSymlink = pkgs.mkOutOfStoreSymlink;
    helixRoot = "${host.flakeRoot}/modules/helix";
    nixTidy = inputs.nix-tidy.packages.${pkgs.stdenv.hostPlatform.system}.default;

    helixSteelPackage =
      (inputs.helix-steel.packages.${pkgs.stdenv.hostPlatform.system}.default.override {
        includeGrammarIf = _: false;
      }).overrideAttrs
      (prevAttrs: {
        patches =
          (prevAttrs.patches or [])
          ++ [
            ./patches/search-in-directory.patch
            ./patches/steel-fixes.patch
          ];
        cargoBuildFeatures = (prevAttrs.cargoBuildFeatures or []) ++ ["steel"];
      });

    hx = pkgs.symlinkJoin {
      name = "hx";
      paths = [helixSteelPackage];
      nativeBuildInputs = [pkgs.makeWrapper];
      postBuild = ''
        wrapProgram $out/bin/hx \
          --set HELIX_STEEL_CONFIG "${config.path.config}/helix/plugins" \
          --prefix PATH : ${
          lib.makeBinPath (
            [
              nixTidy
            ]
            ++ (with pkgs; [
              marksman
              nil
              nixd
              rumdl
              taplo
            ])
          )
        }
      '';
    };

    hxGrammar = pkgs.writeNuScriptBin "hx-grammar-refresh" {
      runtimeInputs = with pkgs; [hx git stdenv.cc];
      source = ''
        def main [...argv: string] {
          hx --grammar fetch
          hx --grammar build ...$argv
        }
      '';
    };
  in {
    options.helix = {
      grammars = lib.mkOption {
        type = lib.types.listOf lib.types.attrs;
        default = [];
      };

      languages = lib.mkOption {
        type = lib.types.listOf lib.types.attrs;
        default = [];
      };

      languageServers = lib.mkOption {
        type = lib.types.attrsOf lib.types.attrs;
        default = {};
      };

      runtimeFiles = lib.mkOption {
        type = lib.types.attrs;
        default = {};
      };
    };

    config = {
      environment.sessionVariables = {
        EDITOR = "hx";
        VISUAL = "hx";
      };
      packages = [
        hx
        hxGrammar
      ];

      file.config =
        {
          "helix/config.toml" = {
            facet = "theme";
            value = facets: let
              theme = facets.theme.value;
            in
              lib.toml.toTOML {
                theme = theme.meta.helix or facets.theme.variant;

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

          "helix/languages.toml".value = lib.toml.toTOML {
            grammar = config.helix.grammars;

            language =
              [
                {
                  name = "rust";
                  language-servers = ["rust-analyzer"];
                }
                {
                  name = "markdown";
                  language-servers = ["marksman"];
                  formatter = {
                    command = "rumdl";
                    args = [
                      "fmt"
                      "--config"
                      (pkgs.writeText "rumdl.toml" ''
                        [global]
                        enable = ["MD060"]

                        [MD060]
                        style = "aligned"
                        max-width = 0
                      '')
                      "--silent"
                      "-"
                    ];
                  };
                  auto-format = true;
                }
                {
                  name = "nix";
                  language-servers = [
                    "nil"
                    "nixd"
                  ];
                  formatter = {
                    command = "nix-tidy";
                    args = ["--quiet" "--threads" "1"];
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
              ]
              ++ config.helix.languages;

            language-server =
              {
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
              }
              // config.helix.languageServers;
          };

          "helix/plugins".value = mkOutOfStoreSymlink "${helixRoot}/plugins";
        }
        // (config.helix.runtimeFiles
          |> lib.mapAttrs' (path: value: {
            name = "helix/runtime/${path}";
            value.value = value;
          }))
        // ([
            "modus"
            "melissa-light"
            "space-age"
            "gruvbox"
            "ashen"
            "cano"
          ]
          |> map (name: {
            name = "helix/themes/${name}.toml";
            value.value = mkOutOfStoreSymlink "${helixRoot}/themes/${name}.toml";
          })
          |> builtins.listToAttrs);
      effect.helix = {
        on = ["theme"];
        exec = [
          (
            if pkgs.stdenv.isDarwin
            then "/usr/bin/pkill"
            else "${pkgs.procps}/bin/pkill"
          )
          "-USR1"
          "hx"
        ];
        ignoreFailure = true;
      };
    };
  };
}
