{inputs, ...}: {
  inputs.helix-steel = {
    url = "github:mattwparas/helix/steel-event-system";
    inputs.nixpkgs.follows = "nixpkgs";
  };

  commonModules.helix = {
    config,
    lib,
    pkgs,
    ...
  }: let
    mkOutOfStoreSymlink = config.lib.sumi.mkOutOfStoreSymlink;
    helixRoot = "${config.lib.sumi.paths.flakeRootOrErr}/modules/helix";

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
          --set HELIX_STEEL_CONFIG "${config.lib.sumi.paths.config}/helix/plugins" \
          --prefix PATH : ${
          lib.makeBinPath (with pkgs; [
            alejandra
            marksman
            nil
            nixd
            taplo
          ])
        }
      '';
    };

    hxGrammar = pkgs.writeShellApplication {
      name = "hx-grammar-refresh";
      runtimeInputs = with pkgs; [
        hx
        git
        stdenv.cc
      ];
      text = ''
        hx --grammar fetch
        hx --grammar build "$@"
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
      environment = {
        variables = {
          EDITOR = "hx";
          VISUAL = "hx";
        };
        systemPackages = [
          hx
          hxGrammar
        ];
      };

      sumi = {
        configFile =
          {
            "helix/config.toml" = {
              watch = "theme";
              value = ctx: let
                theme = ctx.value;
              in
                lib.toml.toTOML {
                  theme = theme.meta.helix or ctx.variant;

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
        hook.helix = {
          watch = "theme";
          command =
            if pkgs.stdenv.isDarwin
            then "/usr/bin/pkill -USR1 hx || true"
            else "${pkgs.procps}/bin/pkill -USR1 hx || true";
        };
      };
    };
  };
}
