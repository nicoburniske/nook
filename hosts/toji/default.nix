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
      docker
      plugdev
      secrets
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
      roamWeb
      shadps4
      steam
      eden
      bitdo-controller
      kantoOra
      coolercontrol
      mullvad
      qbittorrent
      jai
    ];

    _module.args.host = host;

    programs.nix-ld.enable = true;

    nook.sumi.theme.transparency = {
      light = 1.0;
      dark = 1.0;
      darkOnLight = 1.0;
    };

    programs.noctalia-shell.enable = true;
  };
}
