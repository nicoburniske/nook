{...}: {
  flake.mod.common.tools = {pkgs, ...}: {
    environment.systemPackages = with pkgs; [
      just
      tokei
      gh
      unzip
      zip
      ffmpeg
      ncdu
      fastfetch
      usbutils
    ];
  };
}
