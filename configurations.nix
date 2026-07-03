{
  config,
  inputs,
  lib,
  ...
}: let
  hostLib = lib.extend (_: _: config.flake.lib);
  projectModules = common: platform:
    lib.zipAttrsWith (_: imports: {inherit imports;}) [common platform];
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

  options.mod = lib.mkOption {
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

  options.flake.darwinModules = lib.mkOption {
    type = lib.types.lazyAttrsOf lib.types.deferredModule;
    default = {};
  };

  config.flake = {
    nixosModules = projectModules config.mod.common config.mod.nixos;
    darwinModules = projectModules config.mod.common config.mod.darwin;

    nixosConfigurations =
      config.configurations.nixos
      |> lib.mapAttrs (_: host:
        inputs.nixpkgs.lib.nixosSystem {
          modules = [
            config.flake.nixosModules.lib
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
            config.flake.darwinModules.lib
            host.module
          ];
          specialArgs = {
            inherit inputs;
            lib = hostLib;
          };
        });
  };
}
