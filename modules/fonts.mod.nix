{config, ...}: let
  flakeConfig = config;
in {
  flake.mod.common.fonts = {
    config,
    pkgs,
    lib,
    ...
  }: let
    themeValues = builtins.attrValues config.sumi.facets.theme.variants;
    rolePackages = role:
      themeValues
      |> map (theme: theme.fonts.${role}.package or null)
      |> lib.filter (p: p != null)
      |> lib.unique;
  in {
    fonts.packages =
      (rolePackages "serif")
      ++ (rolePackages "sansSerif")
      ++ (rolePackages "monospace")
      ++ (rolePackages "emoji")
      ++ [pkgs.noto-fonts-cjk-sans]
      |> lib.unique;
  };

  flake.mod.nixos.fonts = {
    config,
    lib,
    ...
  }: let
    themeValues = builtins.attrValues config.sumi.facets.theme.variants;
    roleNames = role:
      themeValues
      |> map (theme: theme.fonts.${role}.name or null)
      |> lib.filter (name: name != null)
      |> lib.unique;
  in {
    imports = [flakeConfig.flake.mod.common.fonts];

    fonts.fontconfig = {
      enable = true;
      defaultFonts = {
        serif = (roleNames "serif") ++ ["Noto Sans CJK JP"];
        sansSerif = (roleNames "sansSerif") ++ ["Noto Sans CJK JP"];
        monospace = (roleNames "monospace") ++ ["Noto Sans CJK JP"];
        emoji = roleNames "emoji";
      };
    };
  };
}
