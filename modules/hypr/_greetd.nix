{
  config,
  host,
  lib,
  pkgs,
  ...
}: let
  regreetCssTemplate = builtins.readFile ./_regreet.css.mustache;
  theme = config.sumi.facets.theme.variants.${config.sumi.facets.theme.default};
  c = theme.colors;

  hexAt = idx: builtins.substring idx 2 c.base01;
  placeholders = [
    "{{base00-hex}}"
    "{{base01-hex}}"
    "{{base02-hex}}"
    "{{base03-hex}}"
    "{{base04-hex}}"
    "{{base05-hex}}"
    "{{base06-hex}}"
    "{{base07-hex}}"
    "{{base08-hex}}"
    "{{base09-hex}}"
    "{{base0A-hex}}"
    "{{base0B-hex}}"
    "{{base0C-hex}}"
    "{{base0D-hex}}"
    "{{base0E-hex}}"
    "{{base0F-hex}}"
    "{{base01-dec-r}}"
    "{{base01-dec-g}}"
    "{{base01-dec-b}}"
  ];
  replacements = [
    c.base00
    c.base01
    c.base02
    c.base03
    c.base04
    c.base05
    c.base06
    c.base07
    c.base08
    c.base09
    c.base0A
    c.base0B
    c.base0C
    c.base0D
    c.base0E
    c.base0F
    (toString (lib.fromHexString (hexAt 0)))
    (toString (lib.fromHexString (hexAt 2)))
    (toString (lib.fromHexString (hexAt 4)))
  ];

  regreetCss = builtins.replaceStrings placeholders replacements regreetCssTemplate;
in {
  programs.hyprland.withUWSM = lib.mkDefault true;

  services.greetd.enable = true;

  programs.regreet = {
    enable = true;
    theme = {
      package = pkgs.adw-gtk3;
      name = "adw-gtk3";
    };
    font = {
      inherit (theme.fonts.sansSerif) package name;
    };
    cursorTheme = {
      package = pkgs.phinger-cursors;
      name = if theme.polarity == "light" then "phinger-cursors-dark" else "phinger-cursors-light";
    };
    extraCss = regreetCss;
    settings = {
      GTK.application_prefer_dark_theme = theme.polarity == "dark";
      background = {
        path = toString theme.image;
        fit = "Cover";
      };
      default_session = {
        command = "${config.programs.hyprland.package}/bin/start-hyprland";
        user = host.user;
      };
    };
  };
}
