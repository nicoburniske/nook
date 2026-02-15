{
  description = "Sumi: facet-based runtime config switching for NixOS";

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
        };
      };

      perSystem = {pkgs, ...}: let
        sumiCli = pkgs.callPackage ./pkgs/sumi-cli.nix {};
        sumiLink = pkgs.callPackage ./pkgs/sumi-link.nix {};
      in {
        formatter = pkgs.alejandra;

        packages = {
          default = sumiCli;
          sumi = sumiCli;
          sumi-link = sumiLink;
        };

        devShells.default = pkgs.mkShell {
          packages = with pkgs; [
            gcc
            rustc
            cargo
            clippy
            rustfmt
            rust-analyzer
          ];
        };

        apps.default = {
          type = "app";
          program = "${sumiCli}/bin/sumi";
        };

        apps.sumi-link = {
          type = "app";
          program = "${sumiLink}/bin/sumi-link";
        };
      };
    };
}
