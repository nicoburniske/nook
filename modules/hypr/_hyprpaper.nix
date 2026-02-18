{pkgs, ...}: {
  sumi.configFile."hypr/hyprpaper.conf" = {
    watch = ["theme"];
    generate = ctx: let
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

  sumi.program.hyprpaper = {
    watch = ["theme"];
    reload = ctx: let
      theme = ctx.values.theme;
      imagePath = toString theme.image;
    in ''
      ${pkgs.hyprland}/bin/hyprctl hyprpaper preload "${imagePath}"
      ${pkgs.hyprland}/bin/hyprctl hyprpaper wallpaper ",${imagePath},cover"
    '';
  };

  systemd.user.services.hyprpaper = {
    description = "Hyprpaper wallpaper daemon";
    partOf = ["hyprland-session.target"];
    after = ["hyprland-session.target"];
    wantedBy = ["hyprland-session.target"];

    unitConfig = {
      StartLimitIntervalSec = 0;
    };

    serviceConfig = {
      ExecStart = "${pkgs.hyprpaper}/bin/hyprpaper";
      Restart = "always";
      RestartSec = 1;
    };
  };
}
