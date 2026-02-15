{
  config,
  inputs,
  ...
}: {
  configurations.darwin.fuji.module = {
    pkgs,
    lib,
    ...
  }: let
    host = {
      name = "fuji";
      user = "nicoburniske";
      homeDirectory = "/Users/nicoburniske";
      flakeRoot = "/Users/nicoburniske/nook";
    };
    themes = import (inputs.self + "/common/themes.nix") {inherit pkgs lib;};
    modules = config.flake.modules.darwin;
  in {
    imports = with modules; [
      ./configuration.nix
      sumi
      fonts
      kitty
      yazi
      fzf
      ohMyPosh
      git
      cargo
      inputs.nix-homebrew.darwinModules.nix-homebrew
      {
        nix-homebrew = {
          enable = true;
          enableRosetta = true;
          user = host.user;
          taps = {
            "homebrew/homebrew-core" = inputs.homebrew-core;
            "homebrew/homebrew-cask" = inputs.homebrew-cask;
          };
          mutableTaps = false;
        };
      }
    ];

    _module.args.host = host;

    sumi = {
      enable = true;
      homeDirectory = host.homeDirectory;
      flakeRoot = host.flakeRoot;
      facets.theme = {
        default = "gruvbox";
        variants = themes;
      };
    };
  };
}
