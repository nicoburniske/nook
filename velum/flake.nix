{
  description = "Velum: theme switching primitives for NixOS";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";

    flake-parts = {
      url = "github:hercules-ci/flake-parts";
      inputs.nixpkgs-lib.follows = "nixpkgs";
    };

    systems.url = "github:nix-systems/default";

    stylix = {
      url = "github:nix-community/stylix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = inputs @ {
    flake-parts,
    systems,
    ...
  }:
    flake-parts.lib.mkFlake {inherit inputs;} {
      systems = import systems;

      flake = {
        nixosModules = {
          default = {...}: {
            imports = [
              inputs.stylix.nixosModules.stylix
              ./modules/nixos.nix
            ];
          };

          velum = {...}: {
            imports = [
              inputs.stylix.nixosModules.stylix
              ./modules/nixos.nix
            ];
          };
        };

        lib = import ./lib;
      };

      perSystem = {pkgs, ...}: let
        velumCli = pkgs.callPackage ./pkgs/velum-cli.nix {};
      in {
        formatter = pkgs.alejandra;

        packages = {
          default = velumCli;
          velum = velumCli;
        };

        apps.default = {
          type = "app";
          program = "${velumCli}/bin/velum";
        };
      };
    };
}
