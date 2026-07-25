{
  config,
  inputs,
  lib,
  ...
}: let
  toNix = lib.generators.toPretty {multiline = false;};
  flakeText = ''
    # DO-NOT-EDIT: file was auto-generated using 'just gen'
    {
      description = ${toNix config.description};
      inputs = ${toNix config.inputs};
      nixConfig = ${toNix config.nixConfig};
      outputs = inputs: import ./flake.output.nix inputs;
    }
  '';
in {
  options = {
    inputs = lib.mkOption {
      type = lib.types.attrsOf lib.types.anything;
      default = {};
    };
    description = lib.mkOption {
      type = lib.types.str;
    };
    nixConfig = lib.mkOption {
      type = lib.types.attrsOf lib.types.anything;
      default = {};
    };
  };

  config = {
    description = "dendritic multi host nix config";

    nixConfig.experimental-features = [
      "nix-command"
      "flakes"
      "pipe-operators"
    ];

    inputs = {
      self.lfs = true;
      nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
      systems.url = "github:nix-systems/default";
      nix-tidy = {
        url = "path:./tidy";
        inputs.nixpkgs.follows = "nixpkgs";
      };
      flake-parts = {
        url = "github:hercules-ci/flake-parts";
        inputs.nixpkgs-lib.follows = "nixpkgs";
      };
    };

    systems = [
      "x86_64-linux"
      "aarch64-linux"
      "aarch64-darwin"
    ];

    perSystem = {
      pkgs,
      system,
      ...
    }: let
      nixTidy = inputs.nix-tidy.packages.${system}.default;
    in {
      formatter = nixTidy;

      packages = {
        nix-tidy = nixTidy;
        gen-flake = pkgs.writeShellScriptBin "gen-flake" ''
          install -m 0644 ${pkgs.writeText "flake.nix" flakeText} flake.nix
          ${nixTidy}/bin/nix-tidy flake.nix
        '';
      };
    };
  };
}
