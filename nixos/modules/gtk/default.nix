{
  config,
  lib,
  pkgs,
  ...
}: let
  configDir = config.lib.sumi.paths.config;
  gtkCssTemplate = builtins.readFile ./gtk.css.mustache;

  bases = [
    "base00"
    "base01"
    "base02"
    "base03"
    "base04"
    "base05"
    "base06"
    "base07"
    "base08"
    "base09"
    "base0A"
    "base0B"
    "base0C"
    "base0D"
    "base0E"
    "base0F"
  ];

  mkGtkCss = theme: let
    c = theme.colors;
    base01 = c.base01;
    hexAt = idx: builtins.substring idx 2 base01;
    placeholders =
      (builtins.map (base: "{{${base}-hex}}") bases)
      ++ [
        "{{base01-dec-r}}"
        "{{base01-dec-g}}"
        "{{base01-dec-b}}"
      ];
    replacements =
      (builtins.map (base: c.${base}) bases)
      ++ [
        (toString (lib.fromHexString (hexAt 0)))
        (toString (lib.fromHexString (hexAt 2)))
        (toString (lib.fromHexString (hexAt 4)))
      ];
  in
    builtins.replaceStrings placeholders replacements gtkCssTemplate;

  mkGtkSettings = theme: let
    fontName = theme.fonts.sansSerif.name;
    fontSize = toString theme.fonts.sizes.applications;
    preferDark =
      if theme.polarity == "dark"
      then "1"
      else "0";
  in ''
    [Settings]
    gtk-font-name=${fontName} ${fontSize}
    gtk-theme-name=adw-gtk3
    gtk-application-prefer-dark-theme=${preferDark}
  '';

  mkGtkrc = theme: let
    fontName = theme.fonts.sansSerif.name;
    fontSize = toString theme.fonts.sizes.applications;
  in ''
    gtk-font-name = "${fontName} ${fontSize}"
    gtk-theme-name = "adw-gtk3"
  '';

  mkFlattenedGtkTheme = theme: let
    css = mkGtkCss theme;
    cssFile = pkgs.writeText "sumi-gtk.css" css;
    suffix = builtins.substring 0 8 theme.colors.base00;
  in
    pkgs.runCommandLocal "sumi-adw-gtk3-${suffix}" {} ''
      cp --recursive "${pkgs.adw-gtk3}/share/themes/adw-gtk3" "$out"
      chmod -R u+w "$out"
      cat "${cssFile}" >> "$out/gtk-3.0/gtk.css"
      cat "${cssFile}" >> "$out/gtk-4.0/gtk.css"
    '';
in {
  programs.dconf.enable = true;

  sumi.programs.gtk = {
    ".gtkrc-2.0".render = mkGtkrc;
    "gtk-3.0/settings.ini".render = mkGtkSettings;
    "gtk-4.0/settings.ini".render = mkGtkSettings;
    "gtk-3.0/gtk.css".render = mkGtkCss;
    "gtk-4.0/gtk.css".render = mkGtkCss;
    ".themes/adw-gtk3".render = mkFlattenedGtkTheme;

    reload = builtins.concatStringsSep " " [
      "if grep -q '^gtk-application-prefer-dark-theme=1' \"${configDir}/gtk-3.0/settings.ini\";"
      "then ${pkgs.dconf}/bin/dconf write /org/gnome/desktop/interface/color-scheme \"'prefer-dark'\" || true;"
      "else ${pkgs.dconf}/bin/dconf write /org/gnome/desktop/interface/color-scheme \"'default'\" || true;"
      "fi"
    ];
  };
}
