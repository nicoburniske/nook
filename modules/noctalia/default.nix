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
    toml = pkgs.formats.toml {};
    settings = import ./_settings.nix;
    colors = import ./_colors.nix;
  in {
    options.programs.noctalia = {
      enable = lib.mkEnableOption "Noctalia shell";
    };

    config = lib.mkIf cfg.enable {
      compositor.startupCommands = [
        "${lib.getExe package} --daemon"
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
        command = "${lib.getExe package} msg config-reload";
      };
    };
  };
}
