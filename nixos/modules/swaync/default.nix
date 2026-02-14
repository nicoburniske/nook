{pkgs, ...}: {
  environment.systemPackages = [
    pkgs.swaynotificationcenter
  ];

  velum.programs.swaync = {
    "swaync/config.json".text = "{}\n";

    "swaync/style.css".render = theme: let
      fontFamily =
        if theme.fonts == null
        then "Berkeley Mono"
        else theme.fonts.sansSerif.name;
      fontSize =
        if theme.fonts == null || !(theme.fonts ? sizes) || !(theme.fonts.sizes ? desktop)
        then "12"
        else toString theme.fonts.sizes.desktop;
      baseCss = builtins.readFile ./base.css;
    in
      with theme.colors.withHashtag;
        ''
          * {
              font-family: "${fontFamily}";
              font-size: ${fontSize}pt;
          }

          @define-color base00 ${base00}; @define-color base01 ${base01};
          @define-color base02 ${base02}; @define-color base03 ${base03};
          @define-color base04 ${base04}; @define-color base05 ${base05};
          @define-color base06 ${base06}; @define-color base07 ${base07};

          @define-color base08 ${base08}; @define-color base09 ${base09};
          @define-color base0A ${base0A}; @define-color base0B ${base0B};
          @define-color base0C ${base0C}; @define-color base0D ${base0D};
          @define-color base0E ${base0E}; @define-color base0F ${base0F};
        ''
        + baseCss;

    reload = "
      ${pkgs.swaynotificationcenter}/bin/swaync-client --reload-config || true;
      ${pkgs.swaynotificationcenter}/bin/swaync-client --reload-css || true
      ";
  };

  systemd.user.services.swaync = {
    description = "Sway Notification Center";
    partOf = ["graphical-session.target"];
    after = ["graphical-session.target"];
    wantedBy = ["graphical-session.target"];

    serviceConfig = {
      ExecStart = "${pkgs.swaynotificationcenter}/bin/swaync";
      Restart = "on-failure";
      RestartSec = 1;
    };
  };
}
