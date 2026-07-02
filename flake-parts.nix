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
      import-tree.url = "github:vic/import-tree";
    };

    outputs = ''
      inputs:
        inputs.flake-parts.lib.mkFlake {inherit inputs;} {
          imports = [
            inputs.flake-parts.flakeModules.modules
            inputs.flake-file.flakeModules.default
            ./flake-parts.nix
            ./configurations.nix
            (inputs.import-tree ./lib)
            (inputs.import-tree ./modules)
            ((inputs.import-tree.filter (inputs.nixpkgs.lib.hasSuffix "/default.nix")) ./hosts)
          ];
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
