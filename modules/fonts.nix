{inputs, ...}: let
  mkFontData = pkgs: lib: let
    themes = import (inputs.self + "/common/themes.nix") {inherit pkgs lib;};
    themeValues = builtins.attrValues themes;

    rolePackages = role:
      lib.unique (
        lib.filter (p: p != null) (map (theme: theme.fonts.${role}.package or null) themeValues)
      );

    roleNames = role:
      lib.unique (
        lib.filter (name: name != null) (map (theme: theme.fonts.${role}.name or null) themeValues)
      );

    allPackages = lib.unique (
      (rolePackages "serif")
      ++ (rolePackages "sansSerif")
      ++ (rolePackages "monospace")
      ++ (rolePackages "emoji")
    );
  in {
    inherit allPackages roleNames;
  };
in {
  flake.modules.nixos.fonts = {
    pkgs,
    lib,
    ...
  }: let
    fontData = mkFontData pkgs lib;
  in {
    fonts = {
      packages = fontData.allPackages;

      fontconfig = {
        enable = true;
        defaultFonts = {
          serif = fontData.roleNames "serif";
          sansSerif = fontData.roleNames "sansSerif";
          monospace = fontData.roleNames "monospace";
          emoji = fontData.roleNames "emoji";
        };
      };
    };
  };

  flake.modules.darwin.fonts = {
    pkgs,
    lib,
    ...
  }: let
    fontData = mkFontData pkgs lib;
  in {
    fonts.packages = fontData.allPackages;
  };
}
