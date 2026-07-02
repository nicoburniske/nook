{...}: let
  mkFontData = config: pkgs: lib: let
    themeValues = builtins.attrValues config.sumi.facets.theme.variants;

    rolePackages = role:
      themeValues
      |> map (theme: theme.fonts.${role}.package or null)
      |> lib.filter (p: p != null)
      |> lib.unique;

    roleNames = role:
      themeValues
      |> map (theme: theme.fonts.${role}.name or null)
      |> lib.filter (name: name != null)
      |> lib.unique;

    cjkFont = {
      package = pkgs.noto-fonts-cjk-sans;
      name = "Noto Sans CJK JP";
    };

    allPackages =
      (rolePackages "serif")
      ++ (rolePackages "sansSerif")
      ++ (rolePackages "monospace")
      ++ (rolePackages "emoji")
      ++ [cjkFont.package]
      |> lib.unique;
  in {
    inherit allPackages roleNames cjkFont;
  };
in {
  flake.modules.nixos.fonts = {
    config,
    pkgs,
    lib,
    ...
  }: let
    f = mkFontData config pkgs lib;
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
    config,
    pkgs,
    lib,
    ...
  }: let
    f = mkFontData config pkgs lib;
  in {
    fonts.packages = f.allPackages;
  };
}
