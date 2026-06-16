{...}: {
  flake.modules.nixos.steam = {
    host,
    pkgs,
    ...
  }: let
    # hack for startup crash
    # https://github.com/NixOS/nixpkgs/issues/324875#issuecomment-2308355036
    steam = pkgs.steam.override (prev: {
      extraPreBwrapCmds =
        (prev.extraPreBwrapCmds or "")
        + ''
          ${pkgs.systemd}/bin/systemctl --user restart pipewire || true
        '';
    });
  in {
    programs.steam = {
      enable = true;
      extest.enable = true;
      package = steam;
      remotePlay.openFirewall = true;
      dedicatedServer.openFirewall = true;
      extraPackages = [
        pkgs.hidapi
        pkgs.zlib
      ];
    };

    environment.systemPackages = [
      pkgs.hidapi
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
