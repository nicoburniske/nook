{...}: {
  flake-file = {
    description = "multi host nix config";
    do-not-edit = ''
      # DO-NOT-EDIT: file was auto-generated using 'just gen'
    '';

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
      flake-file.url = "github:vic/flake-file";
    };

    outputs = ''
      inputs:
        let
          lib = inputs.nixpkgs.lib;
          isModuleFile = file:
            lib.hasSuffix ".mod.nix" file || baseNameOf file == "mod.nix";
          moduleRoots = [
            ./lib
            ./modules
            ./hosts
          ];
        in
          inputs.flake-parts.lib.mkFlake {inherit inputs;} {
            imports =
              [
                inputs.flake-file.flakeModules.default
                ./flake-parts.nix
                ./configurations.nix
              ]
              ++ lib.filter isModuleFile (lib.concatMap lib.filesystem.listFilesRecursive moduleRoots);
          }
    '';
  };

  systems = [
    "x86_64-linux"
    "aarch64-linux"
    "aarch64-darwin"
  ];

  perSystem = {pkgs, ...}: {
    formatter = pkgs.alejandra;
  };
}
