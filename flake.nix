{
  description = "Multi-host Nix configuration for NixOS and macOS";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    
    # Cross-platform
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    
    stylix = {
      url = "github:danth/stylix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    
    # NixOS-specific
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

  outputs = inputs@{ 
    self, 
    nixpkgs, 
    home-manager,
    stylix,
    apple-silicon,
    nix-darwin,
    nix-homebrew,
    homebrew-core,
    homebrew-cask,
    ... 
  }: {
    # NixOS configuration
    nixosConfigurations.snowflake = nixpkgs.lib.nixosSystem {
      system = "aarch64-linux";
      specialArgs = { inherit inputs apple-silicon stylix; };
      modules = [
        ./nixos/configuration.nix
        ./nixos/hardware-configuration.nix
        home-manager.nixosModules.home-manager
        {
          home-manager.useGlobalPkgs = true;
          home-manager.useUserPackages = true;
          home-manager.backupFileExtension = "backup";
          home-manager.users.nico = import ./nixos/home.nix;
          home-manager.sharedModules = [stylix.homeModules.stylix];
        }
      ];
    };
    
    # Darwin configuration
    darwinConfigurations.fuji = nix-darwin.lib.darwinSystem {
      system = "aarch64-darwin";
      modules = [
        ./macos/configuration.nix
        nix-homebrew.darwinModules.nix-homebrew
        {
          nix-homebrew = {
            enable = true;
            enableRosetta = true;
            user = "nico";
            taps = {
              "homebrew/homebrew-core" = homebrew-core;
              "homebrew/homebrew-cask" = homebrew-cask;
            };
            mutableTaps = false;
          };
        }
      ];
    };
    
    # Standalone home-manager configurations for faster rebuilds
    homeConfigurations = let
      mkHomeConfig = system: homeModule: extraModules: 
        home-manager.lib.homeManagerConfiguration {
          pkgs = nixpkgs.legacyPackages.${system};
          modules = [
            homeModule
            stylix.homeModules.stylix
          ] ++ extraModules;
        };
      
      # Load theme definitions
      themeDefinitions = import ./common/stylix.nix { 
        pkgs = nixpkgs.legacyPackages.aarch64-linux; 
        lib = nixpkgs.lib;
      };
      
      # Generate theme-specific configurations
      mkThemeConfigs = system: homeModule: 
        builtins.listToAttrs (
          map (theme: {
            name = "nico@${if system == "aarch64-linux" then "nixos" else "macos"}-${theme.stylix.override.slug}";
            value = mkHomeConfig system homeModule [
              { stylix = nixpkgs.lib.mkForce theme.stylix; }
            ];
          }) themeDefinitions.themes
        );
    in {
      # Default configurations
      "nico@nixos" = mkHomeConfig "aarch64-linux" ./nixos/home.nix [];
      "nico@macos" = mkHomeConfig "aarch64-darwin" ./macos/home.nix [];
    } // (mkThemeConfigs "aarch64-linux" ./nixos/home.nix)
      // (mkThemeConfigs "aarch64-darwin" ./macos/home.nix);
  };
}