{
  homeModules.tools = {pkgs, ...}: {
    packages = with pkgs; [
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
      bluetui
    ];
  };
}
