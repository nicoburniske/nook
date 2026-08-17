let
  themeValues = lib: config:
    config.seni.users
    |> lib.filterAttrs (_: user: user.enable)
    |> builtins.attrValues
    |> lib.concatMap (user: builtins.attrValues user.facet.theme.variants);
in {
  commonModules.fonts = {
    config,
    pkgs,
    lib,
    ...
  }: let
    themes = themeValues lib config;
    rolePackages = role:
      themes
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

  nixosModules.fonts = {
    config,
    lib,
    ...
  }: let
    themes = themeValues lib config;
    roleNames = role:
      themes
      |> map (theme: theme.fonts.${role}.name or null)
      |> lib.filter (name: name != null)
      |> lib.unique;
  in {
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
