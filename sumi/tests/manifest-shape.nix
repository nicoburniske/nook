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
              generate = ctx: "tone=${ctx.values.theme.tone}";
            };

            program.demo = {
              watch = ["theme"];
              reload = "echo reload";
            };

            program."demo-generated" = {
              watch = ["theme"];
              reload = ctx: "echo tone=${ctx.values.theme.tone}";
            };
          };
        };
      })
    ];
  };

  manifest = eval.config.sumi.generated.manifest;
  expected = builtins.toJSON {
    version = 1;
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
        executable = false;
        rules = [
          {
            when = {
              theme = ["dark"];
            };
          }
          {
            when = {
              theme = ["light"];
            };
          }
        ];
      }
    ];
    hooks = {
      reload = [
        {
          command = "echo reload";
          registration = "demo";
          when = {
            theme = ["dark"];
          };
        }
        {
          command = "echo reload";
          registration = "demo";
          when = {
            theme = ["light"];
          };
        }
        {
          command = "echo tone=dark";
          registration = "demo-generated";
          when = {
            theme = ["dark"];
          };
        }
        {
          command = "echo tone=light";
          registration = "demo-generated";
          when = {
            theme = ["light"];
          };
        }
      ];
    };
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
