{inputs, ...}: {
  inputs.noctalia = {
    url = "github:noctalia-dev/noctalia";
    inputs.nixpkgs.follows = "nixpkgs";
  };

  nixosModules.noctalia = {
    lib,
    pkgs,
    ...
  }: let
    package = inputs.noctalia.packages.${pkgs.stdenv.hostPlatform.system}.default;
    noctalia = lib.getExe package;
    settings = import ./_settings.nix;
    colors = import ./_colors.nix;
  in {
    compositor = {
      startupCommands = [
        "${noctalia} --daemon"
      ];
      niri.config = [
        {
          layer-rule = {
            match.namespace = "^noctalia-wallpaper$";
            place-within-backdrop = true;
          };
        }

        {
          layer-rule = {
            match.namespace = "^noctalia-bar-";
            background-effect = [{blur = false;}];
          };
        }
      ];
    };

    environment.systemPackages = [
      pkgs.ddcutil
      package
    ];

    sumi = {
      configFile = {
        "noctalia/config.toml" = {
          watch = "theme";
          value = ctx: lib.toml.toTOML (settings ctx.value);
        };

        "noctalia/palettes/Nook.json" = {
          watch = "theme";
          value = ctx: let
            palette = colors ctx.value;
          in
            builtins.toJSON {
              dark = palette;
              light = palette;
            };
        };
      };
      hook.noctalia = {
        watch = "theme";
        command = ctx: let
          wallpaper = lib.escapeShellArg (toString ctx.value.image);
        in ''
          ${noctalia} msg config-reload || true
          ${noctalia} msg wallpaper-set ${wallpaper} || true
        '';
      };
    };
  };
}
