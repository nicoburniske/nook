{
  config,
  inputs,
  ...
}: {
  configurations.nixos.toji.module = {...}: let
    host = {
      name = "toji";
      user = "nico";
      homeDirectory = "/home/nico";
      flakeRoot = "/home/nico/nook";
    };
    modules = config.flake.modules.nixos;
  in {
    imports = with modules; [
      ./configuration.nix
      asdbctl
      docker
      plugdev
      sumi
      nushell
      fonts
      writeNuScriptBin
      compositor
      niri
      awww
      lock
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
      shadps4
      steam
      bitdo-controller
      coolercontrol
      mullvad
    ];

    _module.args.host = host;

    nook.sumi.theme.transparency = {
      light = 1.0;
      dark = 1.0;
      darkOnLight = 1.0;
    };

    programs.noctalia-shell.enable = true;
  };
}
