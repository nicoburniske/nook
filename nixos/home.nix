{
  pkgs,
  lib,
  ...
}: let
  themeDefinitions = import ../common/stylix.nix {inherit pkgs lib;};
in {
  imports = [
    ../common/git.nix
    ../common/helix.nix
    ../common/oh-my-posh.nix
    ../common/yazi.nix
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

    ./modules/hyprland.nix
    ./modules/waybar.nix
    ./modules/walker.nix
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

  home.packages = with pkgs; [
    ungoogled-chromium
    vlc
    wl-clipboard
    brightnessctl
    wiremix
    jmtpfs
    usbutils
    cutecom
    bluetui
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
