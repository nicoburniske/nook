{
  config,
  inputs,
  ...
}: {
  configurations.nixos.snowflake.module = {
    pkgs,
    lib,
    ...
  }: let
    host = {
      name = "snowflake";
      user = "nico";
      homeDirectory = "/home/nico";
      flakeRoot = "/home/nico/nook";
    };
    themes = import (inputs.self + "/common/themes.nix") {inherit pkgs lib;};
    modules = config.flake.modules.nixos;
  in {
    imports = with modules; [
      ./configuration.nix
      inputs.nix-ld.nixosModules.nix-ld
      sumi
      fonts
      writeNuScriptBin
      compositor
      hypr
      niri
      kitty
      yazi
      rofi
      swaync
      quickshell
      gtk
      helix
      fzf
      ohMyPosh
      lazygit
      opencode
      television
      zsh
      bat
      btop
      comically
      git
      cargo
    ];

    _module.args.host = host;

    programs.nix-ld.dev.enable = true;

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
