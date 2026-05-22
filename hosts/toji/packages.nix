{pkgs, ...}: {
  environment.systemPackages = with pkgs; [
    alejandra
    brightnessctl
    ddcutil
    fd
    ffmpeg
    gh
    just
    lua-language-server
    marksman
    nil
    nixd
    pavucontrol
    ripgrep
    taplo
    unzip
    wl-clipboard
    zip
    nautilus
  ];
}
