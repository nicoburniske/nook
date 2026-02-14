{pkgs, ...}: {
  imports = [
    ../common/git.nix
    ../common/oh-my-posh.nix
    ../common/fzf.nix
    ../common/opencode.nix
    ../common/cargo.nix
    ../common/comically.nix

    ./hammerspoon
  ];

  home.username = "nicoburniske";
  home.homeDirectory = "/Users/nicoburniske";
  home.stateVersion = "24.05";

  programs.home-manager.enable = true;
  xdg.enable = true;

  fonts.fontconfig.enable = true;

  home.packages = with pkgs; [yq-go];

  launchd.agents = {};
}
