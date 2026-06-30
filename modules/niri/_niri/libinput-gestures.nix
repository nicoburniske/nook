{
  config,
  pkgs,
  ...
}: let
  conf = {
    name = "libinput-gestures.conf";
    path = "${config.lib.sumi.paths.config}/${conf.name}";
    value = ''
      gesture pinch in 4 /run/current-system/sw/bin/noctalia msg panel-toggle launcher
    '';
  };
in {
  environment.systemPackages = [
    pkgs.libinput-gestures
  ];

  compositor.startupCommands = [
    "${pkgs.systemd}/bin/systemctl --user restart libinput-gestures.service"
  ];

  sumi.configFile.${conf.name}.value = conf.value;

  systemd.user.services.libinput-gestures = {
    description = "Map touchpad gestures to commands";
    documentation = ["https://github.com/bulletmark/libinput-gestures"];
    wantedBy = ["graphical-session.target"];
    partOf = ["graphical-session.target"];
    after = ["graphical-session.target"];

    serviceConfig = {
      Type = "simple";
      ExecStart = "${pkgs.libinput-gestures}/bin/libinput-gestures -c ${conf.path}";
      Restart = "on-failure";
      RestartSec = 2;
    };
  };
}
