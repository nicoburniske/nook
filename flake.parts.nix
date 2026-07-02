{
  config,
  lib,
  ...
}: let
  concat = lib.concatStringsSep;
  toNix = lib.generators.toPretty {multiline = false;};
  toNixAttrs = let
    render = path: value:
      if !builtins.isAttrs value
      then "${concat "." path} = ${toNix value};"
      else let
        names = builtins.attrNames value;
      in
        if builtins.length names == 1
        then render (path ++ names) (builtins.getAttr (builtins.head names) value)
        else "${concat "." path} = { ${attrsToString value} };";
    attrsToString = attrs:
      attrs
      |> lib.mapAttrsToList (name: render [name])
      |> concat " ";
  in
    attrs: "{ ${attrsToString attrs} }";
  flakeText = ''
    # DO-NOT-EDIT: file was auto-generated using 'just gen'
    {
      description = ${toNix config.description};
      inputs = ${toNixAttrs config.inputs};
      nixConfig = ${toNixAttrs config.nixConfig};
      outputs = inputs: import ./flake.output.nix inputs;
    }
  '';
in {
  options.inputs = lib.mkOption {
    type = lib.types.attrsOf lib.types.anything;
    default = {};
  };

  options.description = lib.mkOption {
    type = lib.types.str;
  };

  options.nixConfig = lib.mkOption {
    type = lib.types.attrsOf lib.types.anything;
    default = {};
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

    perSystem = {pkgs, ...}: {
      formatter = pkgs.alejandra;

      packages.gen-flake = pkgs.writeShellApplication {
        name = "gen-flake";
        text = ''
          install -m 0644 ${pkgs.writeText "flake.nix" flakeText} flake.nix
          ${pkgs.alejandra}/bin/alejandra flake.nix >/dev/null 2>&1
        '';
      };
    };
  };
}
