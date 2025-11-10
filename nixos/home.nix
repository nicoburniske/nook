{
  pkgs,
  lib,
  ...
}: let
  themeDefinitions = import ../common/stylix.nix {inherit pkgs lib;};
in {
  imports = [
    ../common/git.nix
    ../common/helix/default.nix
    ../common/oh-my-posh.nix
    ../common/yazi/default.nix
    ../common/zsh.nix
    ../common/fzf.nix
    ../common/zoxide.nix
    ../common/ghostty.nix
    ../common/kitty.nix
    ../common/opencode.nix
    ../common/lazygit.nix
    ../common/cargo.nix
    ../common/packages.nix
    ../common/comically.nix
    ../common/theme-switcher.nix
    ../common/zen-browser.nix
    ../common/television.nix

    ./modules/hyprland.nix
    ./modules/waybar.nix
    ./modules/swaync.nix
    ./modules/rofi.nix
  ];

  home.username = "nico";
  home.homeDirectory = "/home/nico";
  home.stateVersion = "24.05";

  programs.home-manager.enable = true;
  programs.zsh.enable = true;

  # Enable dconf for GNOME settings
  dconf.enable = true;

  fonts.fontconfig.enable = true;

  stylix = lib.mkMerge [
    (lib.mkDefault (builtins.head themeDefinitions.themes).stylix)
  ];

  nixpkgs.config.allowUnfree = true;

  home.packages = with pkgs; [
    (ungoogled-chromium.override {enableWideVine = true;})
    vlc
    wl-clipboard
    brightnessctl
    wiremix
    jmtpfs
    usbutils
    cutecom
    bluetui
    obs-studio
    nautilus
    file-roller
    unzip
    sparrow
  ];

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
