{...}: {
  flake.modules.nixos.steam = {
    host,
    pkgs,
    ...
  }: let
    mkGamescopeProfile = name: args:
      pkgs.writeShellScriptBin "gs${name}" ''
        if [ "''${1:-}" = "--" ]; then
          shift
        fi

        ld_preload="''${LD_PRELOAD:-}"
        exec env -u LD_PRELOAD gamescope ${args} -- env \
          LD_PRELOAD="$ld_preload" \
          ENABLE_GAMESCOPE_WSI=1 \
          DXVK_HDR=1 \
          "$@"
      '';
  in {
    # https://github.com/NixOS/nixpkgs/issues/324875#issuecomment-2308355036
    # systemctl --user restart pipewire
    programs.steam = {
      enable = true;
      extest.enable = true;
      remotePlay.openFirewall = true;
      dedicatedServer.openFirewall = true;
      extraPackages = [
        pkgs.hidapi
        pkgs.zlib
      ];
    };

    programs.gamescope = {
      enable = true;
      enableWsi = true;
      capSysNice = false;
    };

    environment.systemPackages = [
      pkgs.hidapi
      (mkGamescopeProfile "2k" "-W 2560 -H 1440 -w 2560 -h 1440 -r 165 -f --adaptive-sync --hdr-enabled --hdr-debug-force-output")
      (mkGamescopeProfile "5k" "-W 5120 -H 2880 -w 5120 -h 2880 -r 165 -f --adaptive-sync --hdr-enabled --hdr-debug-force-output")
    ];

    hardware.uinput.enable = true;
    users.users.${host.user}.extraGroups = ["uinput"];

    services.udev.extraRules = ''
      # Steam Controller / Triton firmware updater bootloader access.
      SUBSYSTEMS=="usb", ATTRS{idVendor}=="28de", MODE="0666", TAG+="uaccess"
      SUBSYSTEM=="hidraw", ATTRS{idVendor}=="28de", MODE="0666", TAG+="uaccess"
      SUBSYSTEM=="tty", ATTRS{idVendor}=="28de", MODE="0666", TAG+="uaccess"
    '';
  };
}
