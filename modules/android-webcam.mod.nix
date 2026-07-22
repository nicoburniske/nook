{
  nixosModules.android-webcam = {
    config,
    lib,
    pkgs,
    ...
  }: {
    systemd.user.services.android-webcam = {
      description = "Android webcam";
      wantedBy = ["graphical-session.target"];
      partOf = ["graphical-session.target"];
      after = ["graphical-session.target"];
      serviceConfig = {
        ExecStartPre = "${pkgs.android-tools}/bin/adb wait-for-usb-device";
        ExecStart = lib.escapeShellArgs [
          "${pkgs.scrcpy}/bin/scrcpy"
          "--select-usb"
          "--video-source=camera"
          "--camera-facing=back"
          "--max-size=1920"
          "--camera-ar=16:9"
          "--camera-fps=30"
          "--v4l2-sink=/dev/video20"
          "--capture-orientation=@90"
          "--no-audio"
          "--no-window"
        ];
        Restart = "always";
        RestartSec = 2;
        TimeoutStartSec = "infinity";
      };
    };

    boot = {
      extraModulePackages = [config.boot.kernelPackages.v4l2loopback];
      kernelModules = ["v4l2loopback"];
      extraModprobeConfig = ''
        options v4l2loopback devices=1 video_nr=20 card_label="Android Webcam" exclusive_caps=1
      '';
    };

    environment.systemPackages = with pkgs; [
      android-tools
      scrcpy
      v4l-utils
    ];
  };
}
