{
  homeModules.bat = {
    lib,
    pkgs,
    ...
  }: {
    packages = [pkgs.bat];

    file.config = {
      "bat/config".value = "--theme=base16-seni\n";

      "bat/themes/base16-seni.tmTheme" = {
        facet = "theme";
        value = facets: let
          theme = facets.theme.value;
        in
          lib.seni.renderBase16Mustache {
            inherit theme;
            template = ./base16-seni.mustache;
          };
      };
    };
    effect.bat = {
      on = ["theme"];
      exec = [(lib.getExe pkgs.bat) "cache" "--build"];
    };
  };
}
