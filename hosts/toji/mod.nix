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
    common = config.flake.mod.common;
    modules = config.flake.mod.nixos;
  in {
    imports =
      [
        ./configuration.nix
      ]
      ++ (with common; [
        nix
        nushell
        helix
        codex
        fzf
        ohMyPosh
        lazygit
        television
        bat
        btop
        git
        cargo
      ])
      ++ (with modules; [
        docker
        plugdev
        secrets
        sumi
        fonts
        compositor
        niri
        lock
        greet
        kitty
        keepassxc
        nautilus
        fuzzel
        noctalia
        qt
        gtk
        zsh
        helium
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
      ]);

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
