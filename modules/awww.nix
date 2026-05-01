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

    systemd.user.services.awww = {
      description = "awww wallpaper daemon";
      bindsTo = ["compositor-session.target"];
      after = ["compositor-session.target"];
      wantedBy = ["compositor-session.target"];

      serviceConfig = {
        ExecStart = awwwDaemon;
        ExecStartPost = "${pkgs.bash}/bin/bash ${setWallpaper}";
        Restart = "on-failure";
      };
    };

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
