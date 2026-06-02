{...}: {
  flake.modules.nixos.bitdo-controller = {pkgs, ...}: {
    services.udev.extraRules = ''
      # Pro 3 2.4G receiver active mode. Force xpad to treat it as an XInput pad.
      ACTION=="add", SUBSYSTEM=="usb", ATTR{idVendor}=="2dc8", ATTR{idProduct}=="310b", \
        ENV{MTP_NO_PROBE}="1", MODE="0666", \
        RUN+="${pkgs.kmod}/bin/modprobe xpad", \
        RUN+="${pkgs.runtimeShell} -c 'echo 2dc8 310b > /sys/bus/usb/drivers/xpad/new_id || true'"

      # The receiver can expose keyboard/mouse HID surfaces alongside the gamepad.
      SUBSYSTEM=="input", ATTRS{name}=="8BitDo 8BitDo Pro 3 Receiver Keyboard", ENV{LIBINPUT_IGNORE_DEVICE}="1"
      SUBSYSTEM=="input", ATTRS{name}=="8BitDo 8BitDo Pro 3 Receiver Mouse", ENV{LIBINPUT_IGNORE_DEVICE}="1"
    '';
  };
}
