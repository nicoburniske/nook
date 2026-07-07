{
  description = "Sumi: facet-based runtime config switching for NixOS and nix-darwin";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
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
            if ! ${config.sumi.package}/bin/sumi switch; then
              echo "sumi: switch failed during activation" >&2
            fi
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
          system.activationScripts.postActivation.text = lib.mkAfter ''
            if ! ${config.sumi.package}/bin/sumi switch; then
              echo "sumi: switch failed during activation" >&2
            fi
          '';
        };
      };
    }
    // forAllSystems (system: let
      pkgs = nixpkgs.legacyPackages.${system};
      sumi = pkgs.callPackage ./cli/default.nix {};
    in {
      packages = {
        default = sumi;
        inherit sumi;
      };

      checks = {
        manifest-shape = pkgs.callPackage ./tests/manifest-shape.nix {
          lib = pkgs.lib;
        };
        path-materialization = pkgs.callPackage ./tests/path-materialization.nix {
          lib = pkgs.lib;
        };
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
          program = "${sumi}/bin/sumi";
        };
      };
    });
}
