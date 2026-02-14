{pkgs, ...}: {
  velum.programs.hyprpaper = {
    "hypr/hyprpaper.conf".render = theme: let
      imagePath =
        if theme.image == null
        then ""
        else toString theme.image;
    in ''
      preload=${imagePath}
      wallpaper=,${imagePath}
      splash=false
    '';

    reload = "${pkgs.systemd}/bin/systemctl --user restart hyprpaper.service || true";
  };

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
