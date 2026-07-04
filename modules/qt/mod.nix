{
  nixosModules.qt = {
    config,
    lib,
    pkgs,
    ...
  }: let
    mkQtctSettings = theme: let
      fontSize = toString theme.fonts.sizes.applications;
    in ''
      [Appearance]
      custom_palette=true
      icon_theme=Numix-Circle
      standard_dialogs=default
      style=kvantum

      [Fonts]
      fixed="${theme.fonts.monospace.name},${fontSize}"
      general="${theme.fonts.sansSerif.name},${fontSize}"
    '';

    mkKvantumConfig = theme:
      config.lib.sumi.renderBase16Mustache {
        inherit theme;
        template = ./kvconfig.mustache;
      };

    mkKvantumSvg = theme:
      config.lib.sumi.renderBase16Mustache {
        inherit theme;
        template = ./kvantum.svg.mustache;
      };
  in {
    qt = {
      enable = true;
      platformTheme = "qt5ct";
      style = "kvantum";
    };

    environment.systemPackages = [
      pkgs.numix-icon-theme-circle
    ];

    sumi.configFile = {
      "qt5ct/qt5ct.conf" = {
        watch = "theme";
        value = ctx: mkQtctSettings ctx.value;
      };

      "qt6ct/qt6ct.conf" = {
        watch = "theme";
        value = ctx: mkQtctSettings ctx.value;
      };

      "Kvantum/kvantum.kvconfig".value = ''
        [General]
        theme=Base16Kvantum
      '';

      "Kvantum/Base16Kvantum/Base16Kvantum.kvconfig" = {
        watch = "theme";
        value = ctx: mkKvantumConfig ctx.value;
      };

      "Kvantum/Base16Kvantum/Base16Kvantum.svg" = {
        watch = "theme";
        value = ctx: mkKvantumSvg ctx.value;
      };
    };
  };
}
