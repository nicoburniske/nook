{inputs, ...}: {
  flake-file.inputs.noctalia = {
    url = "github:noctalia-dev/noctalia";
    inputs.nixpkgs.follows = "nixpkgs";
  };

  flake.modules.nixos.noctalia = {
    config,
    lib,
    pkgs,
    ...
  }: let
    cfg = config.programs.noctalia;
    package = inputs.noctalia.packages.${pkgs.stdenv.hostPlatform.system}.default;
    noctalia = lib.getExe package;
    toml = pkgs.formats.toml {};
    settings = import ./_settings.nix;
    colors = import ./_colors.nix;
  in {
    options.programs.noctalia = {
      enable = lib.mkEnableOption "Noctalia shell";
    };

    config = lib.mkIf cfg.enable {
      compositor.startupCommands = [
        "${noctalia} --daemon"
      ];

      compositor.niri.rules = [
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

      environment.systemPackages = [
        pkgs.ddcutil
        package
      ];

      sumi.configFile = {
        "noctalia/config.toml" = {
          watch = ["theme"];
          value = ctx: toml.generate "noctalia-config.toml" (settings ctx.values.theme);
        };

        "noctalia/palettes/Nook.json" = {
          watch = ["theme"];
          value = ctx: let
            palette = colors ctx.values.theme;
          in
            builtins.toJSON {
              dark = palette;
              light = palette;
            };
        };
      };

      sumi.hook.noctalia = {
        watch = ["theme"];
        command = ctx: let
          wallpaper = lib.escapeShellArg (toString ctx.values.theme.image);
        in ''
          ${noctalia} msg config-reload || true
          ${noctalia} msg wallpaper-set ${wallpaper} || true
        '';
      };
    };
  };
}
