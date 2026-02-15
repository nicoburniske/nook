{
  lib,
  pkgs,
  ...
}: let
  themes = import ../common/themes.nix {inherit pkgs lib;};
in {
  sumi = {
    enable = true;
    homeDirectory = "/home/nico";
    flakeRoot = "/home/nico/nook";
    facets.theme = {
      default = "gruvbox";
      variants = themes;
    };
  };
}
