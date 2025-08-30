{ pkgs, ... }: {
  home.packages = with pkgs; [
    ripgrep
    lazygit
    delta
    btop
    tokei
    nil
    marksman
    bun
    ffmpeg
    lua-language-server
    rustup
    scooter
    cmake
    neofetch
  ];
}