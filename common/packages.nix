{pkgs, ...}: {
  home.packages = with pkgs; [
    just
    gh
    ripgrep
    delta
    btop
    tokei
    nil
    marksman
    bun
    ffmpeg
    lua-language-server
    rustup
    cmake
    neofetch
    qbittorrent
    alejandra
  ];
}
