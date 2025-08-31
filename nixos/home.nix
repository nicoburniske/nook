{ config, pkgs, lib, ... }: 
let
  themeDefinitions = import ../common/stylix.nix {inherit pkgs lib;};
in {
  imports = [
    # Common configurations
    ../common/git.nix
    ../common/helix.nix
    ../common/starship.nix
    ../common/zellij.nix
    ../common/yazi.nix
    ../common/zsh.nix
    ../common/fzf.nix
    ../common/zoxide.nix
    ../common/ghostty.nix
    ../common/opencode.nix
    ../common/lazygit.nix
    ../common/cargo.nix
    ../common/scooter.nix
    ../common/packages.nix
    
    # Linux-specific modules
    ./modules/hyprland.nix
    ./modules/waybar.nix
    ./modules/swaylock.nix
    ./modules/walker.nix
  ];

  home.username = "nico";
  home.homeDirectory = "/home/nico";
  home.stateVersion = "24.05";
  
  programs.home-manager.enable = true;
  
  # Enable dconf for GNOME settings
  dconf.enable = true;
  
  fonts.fontconfig.enable = true;
  
  stylix = lib.mkMerge [
    (lib.mkDefault (builtins.head themeDefinitions.themes).stylix)
  ];

  # Linux-specific packages
  home.packages = with pkgs; [
    # Additional Linux-specific packages can go here
  ];

  # Theme specialisations
  specialisation = builtins.listToAttrs (
    map (theme: {
      name = theme.stylix.override.slug;
      value = {
        configuration = {
          stylix = lib.mkForce theme.stylix;
        };
      };
    })
    themeDefinitions.themes
  );
}