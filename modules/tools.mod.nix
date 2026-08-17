{
  homeModules.tools = {
    lib,
    pkgs,
    ...
  }: {
    packages =
      (with pkgs; [
        fastfetch
        ffmpeg
        gh
        just
        ncdu
        ripgrep
        tokei
        unzip
        zip
      ])
      ++ lib.optionals pkgs.stdenv.hostPlatform.isLinux (with pkgs; [
        bluetui
        cheese
        usbutils
      ]);
  };
}
