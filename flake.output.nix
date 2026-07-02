inputs: let
  lib = inputs.nixpkgs.lib;
in
  inputs.flake-parts.lib.mkFlake {inherit inputs;} {
    imports =
      [
        ./flake.parts.nix
        ./configurations.nix
      ]
      ++ (
        [
          ./lib
          ./modules
          ./hosts
        ]
        |> lib.concatMap lib.filesystem.listFilesRecursive
        |> lib.filter (file: lib.hasSuffix ".mod.nix" file || baseNameOf file == "mod.nix")
      );
  }
