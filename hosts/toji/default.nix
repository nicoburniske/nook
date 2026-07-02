{config, ...}: {
  flake-file.inputs.nix-ld = {
    url = "github:Mic92/nix-ld";
    inputs.nixpkgs.follows = "nixpkgs";
  };

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
      compositor
      niri
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

    compositor.niri.config = [
      {
        output = {
          args = ["DP-3"];
          children = [
            {mode = "5120x2880@165.058";}
            {scale = 2;}
            {variable-refresh-rate = {};}
            {hdr = {};}
          ];
        };
      }
    ];

    programs.noctalia.enable = true;
  };
}
