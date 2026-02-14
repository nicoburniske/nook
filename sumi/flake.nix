{
  description = "Sumi: theme switching primitives for NixOS";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";

    flake-parts = {
      url = "github:hercules-ci/flake-parts";
      inputs.nixpkgs-lib.follows = "nixpkgs";
    };

    systems.url = "github:nix-systems/default";
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
              ./modules/nixos.nix
            ];
          };

          sumi = {...}: {
            imports = [
              ./modules/nixos.nix
            ];
          };
        };

        lib = import ./lib;
      };

      perSystem = {pkgs, ...}: let
        sumiCli = pkgs.callPackage ./pkgs/sumi-cli.nix {};
      in {
        formatter = pkgs.alejandra;

        packages = {
          default = sumiCli;
          sumi = sumiCli;
        };

        apps.default = {
          type = "app";
          program = "${sumiCli}/bin/sumi";
        };
      };
    };
}
