{...}: {
  flake.modules.nixos.steam = {
    host,
    pkgs,
    ...
  }:
  # https://github.com/NixOS/nixpkgs/issues/324875#issuecomment-2308355036
  # systemctl --user restart pipewire
  {
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
