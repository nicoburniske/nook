{pkgs, ...}: {
  environment.systemPackages = with pkgs; [
    just
    gh
    ripgrep
    tokei
    marksman
    bun
    ffmpeg
    lua-language-server
    rustup
    cmake
    fastfetch
    qbittorrent
    alejandra
    taplo
    presenterm
  ];
}
