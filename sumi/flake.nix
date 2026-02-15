{
  description = "Sumi: facet-based runtime config switching for NixOS and nix-darwin";

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
          default = {
            config,
            lib,
            ...
          }: {
            imports = [
              ./default.nix
            ];

            config = lib.mkIf (config.sumi.enable or false) {
              system.userActivationScripts.sumi = ''
                ${config.sumi.package}/bin/sumi switch || true
              '';
            };
          };
        };

        darwinModules = {
          default = {
            config,
            lib,
            ...
          }: {
            imports = [
              ./default.nix
            ];

            config = lib.mkIf (config.sumi.enable or false) {
              system.activationScripts.sumi.text = ''
                ${config.sumi.package}/bin/sumi switch || true
              '';
            };
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
