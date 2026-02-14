{
  pkgs,
  lib,
  ...
}: let
  themeDefinitions = import ../common/stylix.nix {inherit pkgs lib;};
in {
  imports = [];

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

  home.packages = [];

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
