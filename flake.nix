{
  description = "Multi-host Nix configuration for NixOS and macOS";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    
    stylix = {
      url = "github:danth/stylix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    zen-browser = {
      url = "github:0xc000022070/zen-browser-flake";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    opencode-flake = {
      url = "github:mikael-lindstrom/opencode-flake";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    
    # nixos
    hyprland = {
      url = "github:hyprwm/Hyprland";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    
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
    hyprland,
    apple-silicon,
    nix-darwin,
    nix-homebrew,
    homebrew-core,
    homebrew-cask,
    zen-browser,
    opencode-flake,
    ... 
  }: {
    nixosConfigurations.snowflake = nixpkgs.lib.nixosSystem {
      system = "aarch64-linux";
      specialArgs = { inherit inputs apple-silicon stylix hyprland; };
      modules = [
        ./nixos/configuration.nix
        ./nixos/hardware-configuration.nix
        home-manager.nixosModules.home-manager
        {
          home-manager.useUserPackages = true;
          home-manager.backupFileExtension = "backup";
          home-manager.extraSpecialArgs = { inherit inputs; };
          home-manager.users.nico = import ./nixos/home.nix;
          home-manager.sharedModules = [
            stylix.homeModules.stylix
            zen-browser.homeModules.twilight
          ];
        }
      ];
    };
    
    darwinConfigurations.fuji = nix-darwin.lib.darwinSystem {
      system = "aarch64-darwin";
      specialArgs = { inherit inputs stylix; };
      modules = [
        ./macos/configuration.nix
        home-manager.darwinModules.home-manager
        {
          home-manager.useUserPackages = true;
          home-manager.backupFileExtension = "backup";
          home-manager.extraSpecialArgs = { inherit inputs; };
          home-manager.users.nicoburniske = import ./macos/home.nix;
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
    
    homeConfigurations = {
      "nico@nixos" = home-manager.lib.homeManagerConfiguration {
        pkgs = nixpkgs.legacyPackages.aarch64-linux;
        modules = [
          ./nixos/home.nix
          stylix.homeModules.stylix
          zen-browser.homeModules.twilight
        ];
      };
      
      "nicoburniske@macos" = home-manager.lib.homeManagerConfiguration {
        pkgs = nixpkgs.legacyPackages.aarch64-darwin;
        modules = [
          ./macos/home.nix
          stylix.homeModules.stylix
        ];
      };
    };
  };
}
