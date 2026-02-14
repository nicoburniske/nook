{pkgs, ...}: {
  home.packages = with pkgs; [
    just
    gh
    ripgrep
    delta
    tokei
    marksman
    bun
    ffmpeg
    lua-language-server
    rustup
    cmake
    neofetch
    qbittorrent
    alejandra
    taplo
    fd
    presenterm
  ];
}
