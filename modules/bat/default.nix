{...}: let
  batModule = {
    config,
    pkgs,
    ...
  }: {
    environment.systemPackages = [pkgs.bat];

    sumi.configFile = {
      "bat/config".value = "--theme=base16-sumi\n";

      "bat/themes/base16-sumi.tmTheme" = {
        watch = ["theme"];
        value = ctx: let
          theme = ctx.values.theme;
        in
          config.lib.sumi.renderBase16Mustache {
            inherit theme;
            template = ./base16-sumi.mustache;
          };
      };
    };

    sumi.hook.bat = {
      watch = ["theme"];
      command = "bat cache --build";
    };
  };
in {
  flake.modules.nixos.bat = batModule;
  flake.modules.darwin.bat = batModule;
}
