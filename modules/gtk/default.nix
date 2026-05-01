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
    mkGtkCss = theme:
      config.lib.sumi.renderBase16Mustache {
        inherit theme;
        template = ./gtk.css.mustache;
      };

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
      gtk-error-bell=0
      gtk-enable-event-sounds=0
      gtk-enable-input-feedback-sounds=0
      ${lib.optionalString (gtkVersion == 4) "gtk-interface-color-scheme=${gtk4ColorScheme}"}
    '';

    mkGtkrc = theme: let
      fontName = theme.fonts.sansSerif.name;
      fontSize = toString theme.fonts.sizes.applications;
    in ''
      gtk-font-name = "${fontName} ${fontSize}"
      gtk-theme-name = "${gtkThemeName}"
      gtk-error-bell = 0
      gtk-enable-event-sounds = 0
      gtk-enable-input-feedback-sounds = 0
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
        value = ctx: mkGtkrc ctx.values.theme;
      };
      "gtk-3.0/settings.ini" = {
        watch = ["theme"];
        value = ctx: mkGtkSettings 3 ctx.values.theme;
      };
      "gtk-4.0/settings.ini" = {
        watch = ["theme"];
        value = ctx: mkGtkSettings 4 ctx.values.theme;
      };
      "gtk-3.0/gtk.css" = {
        watch = ["theme"];
        value = ctx: mkGtkCss ctx.values.theme;
      };
      "gtk-4.0/gtk.css" = {
        watch = ["theme"];
        value = ctx: mkGtkCss ctx.values.theme;
      };
    };

    sumi.homeFile = {
      ".themes/${gtkThemeName}" = {
        watch = ["theme"];
        value = ctx: mkFlattenedGtkTheme ctx.values.theme;
      };
    };

    sumi.dataFile = {
      "flatpak/overrides/global".value = ''
        [Context]
        filesystems=${homeDir}/.themes/${gtkThemeName}:ro

        [Environment]
        GTK_THEME=${gtkThemeName}
      '';
    };

    sumi.hook.gtk = {
      watch = ["theme"];
      command = ctx:
        if ctx.values.theme.polarity == "dark"
        then "${pkgs.dconf}/bin/dconf write /org/gnome/desktop/interface/color-scheme \"'prefer-dark'\" || true"
        else "${pkgs.dconf}/bin/dconf write /org/gnome/desktop/interface/color-scheme \"'default'\" || true";
    };
  };
}
