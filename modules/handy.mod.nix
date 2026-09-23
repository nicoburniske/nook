{
  nixosModules.handy = {
    config,
    lib,
    pkgs,
    ...
  }: let
    inherit (lib.kdl) node;
    cfg = config.nook.handy;
    handy = lib.getExe pkgs.handy;
  in {
    options.nook.handy.keybind = lib.mkOption {
      type = lib.types.str;
      default = "Mod+R";
      description = "niri keybind used to toggle local dictation";
    };

    config = {
      compositor.niri.binds = [
        (node cfg.keybind null [] {
            repeat = false;
            hotkey-overlay-title = "Dictation";
          } [
            (node "spawn" null [handy "--toggle-transcription"] {} [])
          ])
      ];

      systemd.user.services.handy = {
        description = "Local dictation";
        wantedBy = ["graphical-session.target"];
        partOf = ["graphical-session.target"];
        after = ["graphical-session.target"];
        path = [
          pkgs.which
          pkgs.wl-clipboard
          pkgs.wtype
        ];
        serviceConfig = {
          ExecStart = "${handy} --start-hidden";
          Restart = "on-failure";
        };
      };
    };
  };

  homeModules.handy = {
    lib,
    pkgs,
    ...
  }: {
    packages = lib.optionals pkgs.stdenv.hostPlatform.isLinux [
      pkgs.handy
      pkgs.wtype
    ];
  };
}
