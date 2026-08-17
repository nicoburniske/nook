{
  nixosModules.gtk.programs.dconf.enable = true;

  homeModules.gtk = {
    config,
    lib,
    pkgs,
    ...
  }: let
    gtkThemeName = "adw-gtk3";
    mkGtkCss = theme:
      lib.seni.renderBase16Mustache {
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
      cssFile = pkgs.writeText "seni-gtk.css" css;
      suffix = builtins.substring 0 8 theme.colors.base00;
    in
      pkgs.runCommandLocal "seni-${gtkThemeName}-${suffix}" {} ''
        cp --recursive "${pkgs.adw-gtk3}/share/themes/${gtkThemeName}" "$out"
        chmod -R u+w "$out"
        cat "${cssFile}" >> "$out/gtk-3.0/gtk.css"
        cat "${cssFile}" >> "$out/gtk-4.0/gtk.css"
      '';
  in {
    environment.sessionVariables.GTK2_RC_FILES = "${config.path.config}/gtk-2.0/gtkrc";

    file = {
      config = {
        "gtk-2.0/gtkrc" = {
          facet = "theme";
          value = {theme}: mkGtkrc theme.value;
        };
        "gtk-3.0/settings.ini" = {
          facet = "theme";
          value = {theme}: mkGtkSettings 3 theme.value;
        };
        "gtk-4.0/settings.ini" = {
          facet = "theme";
          value = {theme}: mkGtkSettings 4 theme.value;
        };
        "gtk-3.0/gtk.css" = {
          facet = "theme";
          value = {theme}: mkGtkCss theme.value;
        };
        "gtk-4.0/gtk.css" = {
          facet = "theme";
          value = {theme}: mkGtkCss theme.value;
        };
      };
      home.".themes/${gtkThemeName}" = {
        facet = "theme";
        value = {theme}: mkFlattenedGtkTheme theme.value;
      };
      data."flatpak/overrides/global".value = ''
        [Context]
        filesystems=${config.path.home}/.themes/${gtkThemeName}:ro

        [Environment]
        GTK_THEME=${gtkThemeName}
      '';
    };

    effect.gtk = {
      on = ["theme"];
      exec = {theme}: [
        "${pkgs.dconf}/bin/dconf"
        "write"
        "/org/gnome/desktop/interface/color-scheme"
        (
          if theme.value.polarity == "dark"
          then "'prefer-dark'"
          else "'default'"
        )
      ];
      ignoreFailure = true;
    };
  };
}
