{pkgs, ...}: {
  environment.systemPackages = with pkgs; [
    alejandra
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
    phoronix-test-suite
    vkmark
    ripgrep
    taplo
    unzip
    wl-clipboard
    zip
    nautilus
    bluetui
    qbittorrent
  ];
}
