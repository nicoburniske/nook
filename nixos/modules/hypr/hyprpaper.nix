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
    partOf = ["graphical-session.target"];
    after = ["graphical-session.target"];
    wantedBy = ["graphical-session.target"];

    serviceConfig = {
      ExecStart = "${pkgs.hyprpaper}/bin/hyprpaper";
      Restart = "on-failure";
      RestartSec = 1;
    };
  };
}
