{
  nixosModules.qt.qt = {
    enable = true;
    platformTheme = "qt5ct";
    style = "kvantum";
  };
  homeModules.qt = {
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
      lib.seni.renderBase16Mustache {
        inherit theme;
        template = ./kvconfig.mustache;
      };

    mkKvantumSvg = theme:
      lib.seni.renderBase16Mustache {
        inherit theme;
        template = ./kvantum.svg.mustache;
      };
  in {
    packages = [pkgs.numix-icon-theme-circle];

    file.config = {
      "qt5ct/qt5ct.conf" = {
        facet = "theme";
        value = {theme}: mkQtctSettings theme.value;
      };

      "qt6ct/qt6ct.conf" = {
        facet = "theme";
        value = {theme}: mkQtctSettings theme.value;
      };

      "Kvantum/kvantum.kvconfig".value = ''
        [General]
        theme=Base16Kvantum
      '';

      "Kvantum/Base16Kvantum/Base16Kvantum.kvconfig" = {
        facet = "theme";
        value = {theme}: mkKvantumConfig theme.value;
      };

      "Kvantum/Base16Kvantum/Base16Kvantum.svg" = {
        facet = "theme";
        value = {theme}: mkKvantumSvg theme.value;
      };
    };
  };
}
