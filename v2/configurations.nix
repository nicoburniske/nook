{
  config,
  inputs,
  lib,
  ...
}: {
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
    nixosConfigurations = lib.mapAttrs (
      _: host:
        inputs.nixpkgs.lib.nixosSystem {
          modules = [host.module];
          specialArgs = {
            inherit inputs;
            apple-silicon = inputs.apple-silicon;
          };
        }
    ) config.configurations.nixos;

    darwinConfigurations = lib.mapAttrs (
      _: host:
        inputs.nix-darwin.lib.darwinSystem {
          modules = [host.module];
          specialArgs = {inherit inputs;};
        }
    ) config.configurations.darwin;
  };
}
