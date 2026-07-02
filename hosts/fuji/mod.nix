{
  config,
  inputs,
  ...
}: {
  flake-file.inputs = {
    nix-darwin = {
      url = "github:LnL7/nix-darwin";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nix-homebrew.url = "github:zhaofengli-wip/nix-homebrew";

    homebrew-core = {
      url = "github:homebrew/homebrew-core";
      flake = false;
    };

    homebrew-cask = {
      url = "github:homebrew/homebrew-cask";
      flake = false;
    };
  };

  configurations.darwin.fuji.module = {...}: let
    host = {
      name = "fuji";
      user = "nicoburniske";
      homeDirectory = "/Users/nicoburniske";
      flakeRoot = "/Users/nicoburniske/nook";
    };
    common = config.flake.mod.common;
    modules = config.flake.mod.darwin;
  in {
    imports =
      [
        ./configuration.nix
        ./packages.nix
      ]
      ++ (with common; [
        nix
        nushell
        helix
        fzf
        ohMyPosh
        lazygit
        television
        bat
        btop
        comically
        git
        cargo
        yazi
        fonts
      ])
      ++ (with modules; [
        sumi
        kitty
        zsh
        hammerspoon
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
      ]);

    _module.args.host = host;

    nook.sumi.theme.transparency = {
      light = 1.0;
      dark = 1.0;
      darkOnLight = 1.0;
    };
  };
}
