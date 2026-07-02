{
  config,
  inputs,
  lib,
  ...
}: let
  hostLib = lib.extend (_: _: config.flake.lib);
in {
  options.configurations = {
    nixos = lib.mkOption {
      type = lib.types.lazyAttrsOf (
        lib.types.submodule {
          options.module = lib.mkOption {
            type = lib.types.deferredModule;
          };
        }
      );
      default = {};
    };

    darwin = lib.mkOption {
      type = lib.types.lazyAttrsOf (
        lib.types.submodule {
          options.module = lib.mkOption {
            type = lib.types.deferredModule;
          };
        }
      );
      default = {};
    };
  };

  options.flake.mod = lib.mkOption {
    type = lib.types.submodule {
      options = {
        common = lib.mkOption {
          type = lib.types.lazyAttrsOf lib.types.deferredModule;
          default = {};
        };

        nixos = lib.mkOption {
          type = lib.types.lazyAttrsOf lib.types.deferredModule;
          default = {};
        };

        darwin = lib.mkOption {
          type = lib.types.lazyAttrsOf lib.types.deferredModule;
          default = {};
        };
      };
    };
    default = {};
  };

  config.flake = {
    nixosConfigurations =
      config.configurations.nixos
      |> lib.mapAttrs (_: host:
        inputs.nixpkgs.lib.nixosSystem {
          modules = [
            config.flake.mod.common.lib
            host.module
          ];
          specialArgs = {
            inherit inputs;
            lib = hostLib;
          };
        });

    darwinConfigurations =
      config.configurations.darwin
      |> lib.mapAttrs (_: host:
        inputs.nix-darwin.lib.darwinSystem {
          modules = [
            config.flake.mod.common.lib
            host.module
          ];
          specialArgs = {
            inherit inputs;
            lib = hostLib;
          };
        });
  };
}
