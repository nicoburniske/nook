{pkgs, ...}: {
  sumi.file."hypr/hyprpaper.conf" = {
    dependsOn = ["theme"];
    render = ctx: let
      theme = ctx.values.theme;
      imagePath =
        if theme.image == null
        then ""
        else toString theme.image;
    in ''
      splash=false

      wallpaper {
        monitor=*
        path=${imagePath}
        fit_mode=cover
      }
    '';
  };

  sumi.program.hyprpaper.reload = "${pkgs.systemd}/bin/systemctl --user restart hyprpaper.service || true";

  systemd.user.services.hyprpaper = {
    description = "Hyprpaper wallpaper daemon";
    partOf = ["hyprland-session.target"];
    after = ["hyprland-session.target"];
    wantedBy = ["hyprland-session.target"];

    unitConfig = {
      StartLimitIntervalSec = 0;
      ConditionEnvironment = "WAYLAND_DISPLAY";
    };

    serviceConfig = {
      ExecStart = "${pkgs.hyprpaper}/bin/hyprpaper";
      Restart = "always";
      RestartSec = 1;
    };
  };
}
