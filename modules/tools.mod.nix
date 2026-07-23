{
  commonModules.tools = {pkgs, ...}: {
    environment.systemPackages = with pkgs; [
      cheese
      fastfetch
      ffmpeg
      gh
      just
      ncdu
      ripgrep
      tokei
      unzip
      usbutils
      zip
    ];
  };
}
