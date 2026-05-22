{
  config,
  inputs,
  ...
}: {
  configurations.nixos.toji.module = {
    pkgs,
    lib,
    ...
  }: let
    host = {
      name = "toji";
      user = "nico";
      homeDirectory = "/home/nico";
      flakeRoot = "/home/nico/nook";
    };
    themes = import (inputs.self + "/common/themes.nix") {inherit pkgs lib;};
    modules = config.flake.modules.nixos;
  in {
    imports = with modules; [
      ./configuration.nix
      asdbctl
      sumi
      fonts
      writeNuScriptBin
      compositor
      niri
      awww
      greet
      kitty
      fuzzel
      noctalia
      qt
      gtk
      helix
      helium
      codex
      fzf
      ohMyPosh
      lazygit
      television
      zsh
      bat
      btop
      git
      cargo
      spotifyWeb
    ];

    _module.args.host = host;

    programs.noctalia-shell.enable = true;

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
