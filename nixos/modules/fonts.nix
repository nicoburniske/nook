{pkgs, ...}: let
  berkeleyMono = import ../../common/berkeley-mono.nix {inherit pkgs;};
in {
  fonts = {
    packages = [
      berkeleyMono
      pkgs.nerd-fonts.symbols-only
    ];

    fontconfig = {
      enable = true;
      defaultFonts = {
        serif = ["Berkeley Mono"];
        sansSerif = ["Berkeley Mono"];
        monospace = ["Berkeley Mono"];
        emoji = ["Symbols Nerd Font"];
      };
    };
  };
}
