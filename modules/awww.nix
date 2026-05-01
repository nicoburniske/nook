{...}: {
  flake.modules.nixos.awww = {
    config,
    lib,
    pkgs,
    ...
  }: let
    package = pkgs.awww;
    awww = lib.getExe package;
    awwwDaemon = lib.getExe' package "awww-daemon";
    setWallpaper = "${config.lib.sumi.paths.config}/awww/set-wallpaper";
  in {
    environment.systemPackages = [
      package
    ];

    compositor.startupCommands = [
      awwwDaemon
      "${pkgs.bash}/bin/bash ${setWallpaper}"
    ];

    sumi.configFile."awww/set-wallpaper" = {
      watch = ["theme"];
      value = ctx: let
        wallpaper = lib.escapeShellArg (toString ctx.values.theme.image);
      in ''
        ${awww} img ${wallpaper} --resize crop --transition-type none || true
      '';
    };

    sumi.hook.awww = {
      watch = ["theme"];
      command = "${pkgs.bash}/bin/bash ${setWallpaper}";
    };
  };
}
