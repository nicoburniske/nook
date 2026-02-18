{...}: {
  flake.modules.nixos.gtk = {
    config,
    lib,
    pkgs,
    ...
  }: let
    configDir = config.lib.sumi.paths.config;
    homeDir = config.lib.sumi.paths.home;
    gtkThemeName = "adw-gtk3";
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
        (map (base: "{{${base}-hex}}") bases)
        ++ [
          "{{base01-dec-r}}"
          "{{base01-dec-g}}"
          "{{base01-dec-b}}"
        ];
      replacements =
        (map (base: c.${base}) bases)
        ++ [
          (toString (lib.fromHexString (hexAt 0)))
          (toString (lib.fromHexString (hexAt 2)))
          (toString (lib.fromHexString (hexAt 4)))
        ];
    in
      builtins.replaceStrings placeholders replacements gtkCssTemplate;

    mkGtkSettings = gtkVersion: theme: let
      fontName = theme.fonts.sansSerif.name;
      fontSize = toString theme.fonts.sizes.applications;
      preferDark =
        if theme.polarity == "dark"
        then "1"
        else "0";
      gtk4ColorScheme =
        if theme.polarity == "dark"
        then "2"
        else "3";
    in ''
      [Settings]
      gtk-font-name=${fontName} ${fontSize}
      gtk-theme-name=${gtkThemeName}
      gtk-application-prefer-dark-theme=${preferDark}
      ${lib.optionalString (gtkVersion == 4) "gtk-interface-color-scheme=${gtk4ColorScheme}"}
    '';

    mkGtkrc = theme: let
      fontName = theme.fonts.sansSerif.name;
      fontSize = toString theme.fonts.sizes.applications;
    in ''
      gtk-font-name = "${fontName} ${fontSize}"
      gtk-theme-name = "${gtkThemeName}"
    '';

    mkFlattenedGtkTheme = theme: let
      css = mkGtkCss theme;
      cssFile = pkgs.writeText "sumi-gtk.css" css;
      suffix = builtins.substring 0 8 theme.colors.base00;
    in
      pkgs.runCommandLocal "sumi-${gtkThemeName}-${suffix}" {} ''
        cp --recursive "${pkgs.adw-gtk3}/share/themes/${gtkThemeName}" "$out"
        chmod -R u+w "$out"
        cat "${cssFile}" >> "$out/gtk-3.0/gtk.css"
        cat "${cssFile}" >> "$out/gtk-4.0/gtk.css"
      '';
  in {
    programs.dconf.enable = true;
    environment.variables.GTK2_RC_FILES = "${configDir}/gtk-2.0/gtkrc";

    sumi.configFile = {
      "gtk-2.0/gtkrc" = {
        watch = ["theme"];
        generate = ctx: mkGtkrc ctx.values.theme;
      };
      "gtk-3.0/settings.ini" = {
        watch = ["theme"];
        generate = ctx: mkGtkSettings 3 ctx.values.theme;
      };
      "gtk-4.0/settings.ini" = {
        watch = ["theme"];
        generate = ctx: mkGtkSettings 4 ctx.values.theme;
      };
      "gtk-3.0/gtk.css" = {
        watch = ["theme"];
        generate = ctx: mkGtkCss ctx.values.theme;
      };
      "gtk-4.0/gtk.css" = {
        watch = ["theme"];
        generate = ctx: mkGtkCss ctx.values.theme;
      };
    };

    sumi.homeFile = {
      ".themes/${gtkThemeName}" = {
        watch = ["theme"];
        generate = ctx: mkFlattenedGtkTheme ctx.values.theme;
      };
    };

    sumi.dataFile = {
      "flatpak/overrides/global".text = ''
        [Context]
        filesystems=${homeDir}/.themes/${gtkThemeName}:ro

        [Environment]
        GTK_THEME=${gtkThemeName}
      '';
    };

    sumi.program.gtk = {
      watch = ["theme"];
      reload = ctx:
        if ctx.values.theme.polarity == "dark"
        then "${pkgs.dconf}/bin/dconf write /org/gnome/desktop/interface/color-scheme \"'prefer-dark'\" || true"
        else "${pkgs.dconf}/bin/dconf write /org/gnome/desktop/interface/color-scheme \"'default'\" || true";
    };
  };
}
