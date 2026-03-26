{
  lib,
  pkgs,
}: let
  types = lib.types;

  eval = lib.evalModules {
    specialArgs = {
      inherit pkgs;
    };

    modules = [
      ../default.nix
      ({...}: {
        options = {
          assertions = lib.mkOption {
            type = types.listOf types.anything;
            default = [];
          };

          environment = lib.mkOption {
            type = types.attrs;
            default = {};
          };

          lib = lib.mkOption {
            type = types.attrs;
            default = {};
          };
        };

        config = {
          sumi = {
            enable = true;
            homeDirectory = "/home/tester";
            flakeRoot = "/tmp/sumi-tests";

            facets.theme = {
              default = "light";
              variants = {
                light = {
                  tone = "light";
                };

                dark = {
                  tone = "dark";
                };
              };
            };

            defaultSelection.theme = "light";

            configFile."demo/app.conf" = {
              watch = ["theme"];
              value = ctx: "tone=${ctx.values.theme.tone}";
            };

            hook.demo = {
              watch = ["theme"];
              command = "echo reload";
            };

            hook."demo-generated" = {
              watch = ["theme"];
              command = ctx: "echo tone=${ctx.values.theme.tone}";
            };
          };
        };
      })
    ];
  };

  manifest = eval.config.sumi.generated.manifest;
  expected = builtins.toJSON {
    version = 2;
    home = "/home/tester";
    defaultSelection = {
      theme = "light";
    };
    facets = {
      theme = {
        default = "light";
        variants = {
          dark = {
            tone = "dark";
          };
          light = {
            tone = "light";
          };
        };
      };
    };
    files = [
      {
        path = ".config/demo/app.conf";
        dispatch = {
          kind = "select";
          facets = ["theme"];
          cases = [
            {
              variants = ["dark"];
            }
            {
              variants = ["light"];
            }
          ];
        };
      }
    ];
    hooks = [
      {
        name = "demo";
        watch = ["theme"];
        dispatch = {
          kind = "static";
          value = "echo reload";
        };
      }
      {
        name = "demo-generated";
        watch = ["theme"];
        dispatch = {
          kind = "select";
          facets = ["theme"];
          cases = [
            {
              variants = ["dark"];
              value = "echo tone=dark";
            }
            {
              variants = ["light"];
              value = "echo tone=light";
            }
          ];
        };
      }
    ];
  };
in
  pkgs.runCommand "sumi-manifest-shape-test" {
    nativeBuildInputs = [pkgs.nushell];
  } ''
    set -eu

    manifest=${lib.escapeShellArg (toString manifest)}
    expected=${lib.escapeShellArg expected}
    test -f "$manifest"

    ${pkgs.nushell}/bin/nu ${./manifest-shape.nu} "$manifest" "$expected"

    touch "$out"
  ''
