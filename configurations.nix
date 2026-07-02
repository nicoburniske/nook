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

  config.flake = {
    nixosConfigurations =
      lib.mapAttrs (
        _: host:
          inputs.nixpkgs.lib.nixosSystem {
            modules = [
              config.flake.modules.nixos.lib
              host.module
            ];
            specialArgs = {
              inherit inputs;
              lib = hostLib;
            };
          }
      )
      config.configurations.nixos;

    darwinConfigurations =
      lib.mapAttrs (
        _: host:
          inputs.nix-darwin.lib.darwinSystem {
            modules = [
              config.flake.modules.darwin.lib
              host.module
            ];
            specialArgs = {
              inherit inputs;
              lib = hostLib;
            };
          }
      )
      config.configurations.darwin;
  };
}
