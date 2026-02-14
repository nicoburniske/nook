{
  description = "Multi-host Nix configuration for NixOS and macOS";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    nixpkgs-master.url = "github:NixOS/nixpkgs/master";
    opencode.url = "github:anomalyco/opencode/dev";

    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    stylix = {
      url = "github:danth/stylix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    velum.url = "path:./velum";

    nix-ld = {
      url = "github:Mic92/nix-ld";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # nixos
    apple-silicon = {
      url = "github:nix-community/nixos-apple-silicon";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # macOS-specific
    nix-darwin = {
      url = "github:LnL7/nix-darwin";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nix-homebrew.url = "github:zhaofengli-wip/nix-homebrew";

    homebrew-core = {
      url = "github:homebrew/homebrew-core";
      flake = false;
    };

    homebrew-cask = {
      url = "github:homebrew/homebrew-cask";
      flake = false;
    };
  };

  outputs = inputs @ {
    self,
    nixpkgs,
    nixpkgs-master,
    home-manager,
    nix-ld,
    stylix,
    velum,
    apple-silicon,
    nix-darwin,
    nix-homebrew,
    homebrew-core,
    homebrew-cask,
    ...
  }: {
    nixosConfigurations.snowflake = nixpkgs.lib.nixosSystem {
      system = "aarch64-linux";
      specialArgs = {inherit inputs apple-silicon stylix;};
      modules = [
        ./nixos/configuration.nix
        ./nixos/hardware-configuration.nix
        nix-ld.nixosModules.nix-ld
        velum.nixosModules.default
        {
          programs.nix-ld.dev.enable = true;
        }
      ];
    };

    darwinConfigurations.fuji = nix-darwin.lib.darwinSystem {
      system = "aarch64-darwin";
      specialArgs = {inherit inputs stylix;};
      modules = [
        ./macos/configuration.nix
        home-manager.darwinModules.home-manager
        {
          home-manager.useUserPackages = true;
          home-manager.backupFileExtension = "backup";
          home-manager.users.nicoburniske = import ./macos/home.nix;
          home-manager.extraSpecialArgs = {inherit inputs;};
          home-manager.sharedModules = [
            stylix.homeModules.stylix
          ];
        }
        nix-homebrew.darwinModules.nix-homebrew
        {
          nix-homebrew = {
            enable = true;
            enableRosetta = true;
            user = "nicoburniske";
            taps = {
              "homebrew/homebrew-core" = homebrew-core;
              "homebrew/homebrew-cask" = homebrew-cask;
            };
            mutableTaps = false;
          };
        }
      ];
    };
  };
}
