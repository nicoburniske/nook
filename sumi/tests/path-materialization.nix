{
  lib,
  pkgs,
}: let
  types = lib.types;
  fixture = ./path-materialization.nu;

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
                  asset = fixture;
                  tone = "light";
                };

                dark = {
                  asset = fixture;
                  tone = "dark";
                };
              };
            };

            configFile."demo/static-source.txt".value = fixture;

            configFile."demo/asset-path.txt" = {
              watch = "theme";
              value = ctx: "asset=${toString ctx.value.asset}";
            };

            hook."asset-path" = {
              watch = "theme";
              command = ctx: "echo ${toString ctx.value.asset}";
            };
          };
        };
      })
    ];
  };

  manifest = eval.config.sumi.generated.manifest;
in
  pkgs.runCommand "sumi-path-materialization-test" {
    nativeBuildInputs = [pkgs.nushell];
  } ''
    set -eu

    manifest=${lib.escapeShellArg (toString manifest)}
    fixture=${lib.escapeShellArg (toString fixture)}
    test -f "$manifest"

    ${pkgs.nushell}/bin/nu ${./path-materialization.nu} "$manifest" "$fixture"

    touch "$out"
  ''
