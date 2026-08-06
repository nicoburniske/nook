{
  config,
  inputs,
  ...
}: {
  inputs.nix-darwin = {
    url = "github:LnL7/nix-darwin";
    inputs.nixpkgs.follows = "nixpkgs";
  };
  configurations.darwin.fuji.module = {...}: let
    host = {
      name = "fuji";
      user = "nicoburniske";
      homeDirectory = "/Users/nicoburniske";
      flakeRoot = "/Users/nicoburniske/nook";
    };
  in {
    imports =
      [
        ./configuration.nix
        ./packages.nix
      ]
      ++ (with config.flake.darwinModules; [
        nix
        nushell
        helix
        fzf
        oh-my-posh
        lazygit
        television
        bat
        btop
        comically
        git
        cargo
        yazi
        fonts
        qbittorrent
        sumi
        kitty
        helium
        zsh
        hammerspoon
      ]);

    _module.args.host = host;

    nook.sumi.theme.transparency = {
      light = 1.0;
      dark = 1.0;
      darkOnLight = 1.0;
    };
  };
}
