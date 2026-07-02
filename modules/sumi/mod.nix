{inputs, ...}: let
  mkSumiModule = upstreamModule: {
    config,
    host,
    lib,
    pkgs,
    ...
  }: let
    cfg = config.nook.sumi;
    themes = import ./_themes.nix {
      inherit pkgs lib;
      transparency = cfg.theme.transparency;
    };
  in {
    imports = [upstreamModule];

    options.nook.sumi = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = true;
      };

      theme.default = lib.mkOption {
        type = lib.types.str;
        default = "gruvbox";
        description = "default selected theme";
      };

      theme.transparency = lib.mkOption {
        type = lib.types.submodule {
          options = {
            light = lib.mkOption {
              type = lib.types.float;
              default = 0.90;
              description = "opacity for light themes";
            };

            dark = lib.mkOption {
              type = lib.types.float;
              default = 0.90;
              description = "opacity for dark themes";
            };

            darkOnLight = lib.mkOption {
              type = lib.types.float;
              default = 0.93;
              description = "opacity for dark themes with light backgrounds";
            };
          };
        };
        default = {};
      };
    };

    config = lib.mkIf cfg.enable {
      assertions = [
        {
          assertion =
            builtins.attrValues cfg.theme.transparency
            |> lib.all (value: value >= 0.0 && value <= 1.0);
          message = "nook.sumi.theme.transparency values must be between 0.0 and 1.0.";
        }
      ];

      sumi = {
        enable = true;
        homeDirectory = host.homeDirectory;
        flakeRoot = host.flakeRoot;
        facets.theme = {
          default = cfg.theme.default;
          variants = themes;
        };
      };
    };
  };
in {
  inputs.sumi = {
    url = "path:./sumi";
    inputs.nixpkgs.follows = "nixpkgs";
  };

  flake.mod.nixos.sumi = mkSumiModule inputs.sumi.nixosModules.default;
  flake.mod.darwin.sumi = mkSumiModule inputs.sumi.darwinModules.default;
}
