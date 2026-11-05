{inputs, ...}: {
  inputs.hex = {
    url = "github:anomalyco/hex/v3.3.0";
    inputs.nixpkgs.follows = "nixpkgs";
  };

  nixosModules.hex = {
    config,
    lib,
    pkgs,
    ...
  }: let
    inherit (lib.kdl) node;
    cfg = config.nook.hex;
    package = lib.meta.addMetaAttrs {
      platforms = ["x86_64-linux" "aarch64-linux"];
    } (pkgs.callPackage "${inputs.hex}/nix/package.nix" {});
    hex = lib.getExe package;
    waitForSession = pkgs.writeShellApplication {
      name = "hex-wait-for-session";
      runtimeInputs = [
        pkgs.coreutils
        pkgs.gnugrep
        pkgs.xprop
      ];
      text = builtins.readFile "${inputs.hex}/nix/wait-for-session.sh";
    };
  in {
    options.nook.hex.keybind = lib.mkOption {
      type = lib.types.str;
      default = "Mod+R";
      description = "niri keybind used to toggle local dictation";
    };
    config = {
      environment.systemPackages = [package];
      compositor.niri.binds = [
        (node cfg.keybind null [] {
            repeat = false;
            hotkey-overlay-title = "Dictation";
          } [
            (node "spawn" null [hex "dictation" "toggle"] {} [])
          ])
      ];
      systemd.user.services.hex = {
        description = "Local dictation";
        wantedBy = ["graphical-session.target"];
        partOf = ["graphical-session.target"];
        after = ["graphical-session.target"];
        serviceConfig = {
          Type = "notify";
          NotifyAccess = "main";
          ExecStartPre = lib.getExe waitForSession;
          ExecStart = "${hex} service";
          EnvironmentFile = "-%h/.local/share/hex/session.env";
          TimeoutStartSec = 35;
          TimeoutStopSec = 30;
          Restart = "on-failure";
          RestartSec = 5;
          UMask = "0077";
        };
      };
    };
  };
}
