{...}: {
  flake.mod.common.bat = {
    config,
    lib,
    pkgs,
    ...
  }: {
    environment.systemPackages = [pkgs.bat];

    sumi.configFile = {
      "bat/config".value = "--theme=base16-sumi\n";

      "bat/themes/base16-sumi.tmTheme" = {
        watch = "theme";
        value = ctx: let
          theme = ctx.value;
        in
          config.lib.sumi.renderBase16Mustache {
            inherit theme;
            template = ./base16-sumi.mustache;
          };
      };
    };

    sumi.hook.bat = {
      watch = "theme";
      command = "${lib.getExe pkgs.bat} cache --build";
    };
  };
}
