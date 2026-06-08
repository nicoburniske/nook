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

    cjkFont = {
      package = pkgs.noto-fonts-cjk-sans;
      name = "Noto Sans CJK JP";
    };

    allPackages = lib.unique (
      (rolePackages "serif")
      ++ (rolePackages "sansSerif")
      ++ (rolePackages "monospace")
      ++ (rolePackages "emoji")
      ++ [cjkFont.package]
    );
  in {
    inherit allPackages roleNames cjkFont;
  };
in {
  flake.modules.nixos.fonts = {
    pkgs,
    lib,
    ...
  }: let
    f = mkFontData pkgs lib;
  in {
    fonts = {
      packages = f.allPackages;

      fontconfig = {
        enable = true;
        defaultFonts = {
          serif = (f.roleNames "serif") ++ [f.cjkFont.name];
          sansSerif = (f.roleNames "sansSerif") ++ [f.cjkFont.name];
          monospace = (f.roleNames "monospace") ++ [f.cjkFont.name];
          emoji = f.roleNames "emoji";
        };
      };
    };
  };

  flake.modules.darwin.fonts = {
    pkgs,
    lib,
    ...
  }: let
    f = mkFontData pkgs lib;
  in {
    fonts.packages = f.allPackages;
  };
}
