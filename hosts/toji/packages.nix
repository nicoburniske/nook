{pkgs, ...}: {
  environment.systemPackages = with pkgs; [
    alejandra
    asdbctl
    brightnessctl
    fd
    ffmpeg
    gh
    goverlay
    just
    lua-language-server
    mangohud
    marksman
    nil
    nixd
    pulseaudio
    pavucontrol
    ripgrep
    taplo
    unzip
    wl-clipboard
    zip
    nautilus
  ];
}
