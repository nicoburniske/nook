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
  options = {
    configurations = {
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
    commonModules = lib.mkOption {
      type = lib.types.lazyAttrsOf lib.types.deferredModule;
      default = {};
    };
    nixosModules = lib.mkOption {
      type = lib.types.lazyAttrsOf lib.types.deferredModule;
      default = {};
    };
    darwinModules = lib.mkOption {
      type = lib.types.lazyAttrsOf lib.types.deferredModule;
      default = {};
    };
  };

  config.flake = {
    nixosModules = projectModules config.commonModules config.nixosModules;
    darwinModules = projectModules config.commonModules config.darwinModules;

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
