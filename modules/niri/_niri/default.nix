{
  config,
  inputs,
  lib,
  pkgs,
  ...
}: let
  keybinds = import ./keybinds {
    inherit config inputs lib pkgs;
  };

  baseConfig = import ./config.nix {
    inherit config;
  };
  mkTheme = import ./theme.nix {inherit lib;};
  configKdl = lib.kdl.toKDL (
    baseConfig
    ++ config.compositor.niri.config
    ++ (import ./rules.nix)
    ++ [
      {
        binds = keybinds;
      }
    ]
  );
in {
  sumi.configFile = {
    "niri/config.kdl".value = ''
      include "theme.kdl"
      ${configKdl}
    '';

    "niri/theme.kdl" = {
      watch = "theme";
      value = ctx: lib.kdl.toKDL (mkTheme ctx.value);
    };
  };
}
