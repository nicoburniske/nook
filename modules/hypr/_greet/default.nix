{
  config,
  host,
  lib,
  pkgs,
  ...
}: let
  theme = config.sumi.facets.theme.variants.${config.sumi.facets.theme.default};

  regreetCss = config.lib.sumi.renderBase16Mustache {
    inherit theme;
    template = ./regreet.mustache;
  };
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
      name =
        if theme.polarity == "light"
        then "phinger-cursors-dark"
        else "phinger-cursors-light";
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
