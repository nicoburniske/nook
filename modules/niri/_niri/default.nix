{
  config,
  inputs,
  pkgs,
  ...
}: let
  keybinds = import ./keybinds {
    inherit inputs pkgs;
  };

  baseConfig = import ./config.nix {
    inherit config;
  };
  rules = import ./rules.nix;
  mkTheme = import ./theme.nix;
in {
  sumi.configFile = {
    "niri/config.kdl".value = ''
      include "theme.kdl"

      ${baseConfig}

      ${rules}

      binds {
        ${keybinds}
      }
    '';

    "niri/theme.kdl" = {
      watch = ["theme"];
      value = ctx: mkTheme ctx.values.theme;
    };
  };
}
