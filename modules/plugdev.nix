{...}: {
  flake.modules.nixos.plugdev = {host, ...}: {
    services.udev = {
      enable = true;
      extraRules = ''
        SUBSYSTEMS=="usb", ATTRS{idVendor}=="10c4", ATTRS{idProduct}=="ea60", GROUP="plugdev", MODE="0666"
        SUBSYSTEMS=="usb", ATTRS{idVendor}=="1307", ATTRS{idProduct}=="0165", GROUP="plugdev", MODE="0666"
        SUBSYSTEMS=="usb", ATTRS{idVendor}=="03eb", ATTRS{idProduct}=="6124", GROUP="plugdev", MODE="0666"
      '';
    };

    users.groups.plugdev = {};
    users.users.${host.user}.extraGroups = ["plugdev"];
  };
}
