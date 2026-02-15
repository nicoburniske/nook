{
  description = "Sumi: facet-based runtime config switching for NixOS and nix-darwin";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
  };

  outputs = {nixpkgs, ...}: let
    systems = with nixpkgs; lib.systems.flakeExposed;
    forAllSystems = f:
      builtins.foldl' (
        attrs: system: let
          out = f system;
        in
          builtins.foldl' (
            acc: key:
              acc
              // {
                ${key} = (acc.${key} or {}) // {${system} = out.${key};};
              }
          )
          attrs (builtins.attrNames out)
      ) {}
      systems;
  in
    {
      nixosModules.default = {
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

      darwinModules.default = {
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
    }
    // forAllSystems (system: let
      pkgs = nixpkgs.legacyPackages.${system};
      sumiCli = pkgs.callPackage ./pkgs/sumi-cli.nix {};
      sumiLink = pkgs.callPackage ./pkgs/sumi-link.nix {};
    in {
      formatter = pkgs.alejandra;

      packages = {
        default = sumiCli;
        sumi = sumiCli;
        sumi-link = sumiLink;
      };

      devShells = {
        default = pkgs.mkShell {
          packages = with pkgs; [
            gcc
            rustc
            cargo
            clippy
            rustfmt
            rust-analyzer
          ];
        };
      };

      apps = {
        default = {
          type = "app";
          program = "${sumiCli}/bin/sumi";
        };

        sumi-link = {
          type = "app";
          program = "${sumiLink}/bin/sumi-link";
        };
      };
    });
}
