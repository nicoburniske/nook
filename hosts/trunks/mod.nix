{config, ...}: {
  inputs.apple-silicon = {
    url = "github:nix-community/nixos-apple-silicon";
    inputs.nixpkgs.follows = "nixpkgs";
  };

  configurations.nixos.trunks.module = {...}: let
    host = {
      name = "trunks";
      user = "nico";
      homeDirectory = "/home/nico";
      flakeRoot = "/home/nico/nook";
    };
  in {
    imports =
      [
        ./configuration.nix
      ]
      ++ (with config.flake.nixosModules; [
        nix
        nushell
        helix
        fzf
        oh-my-posh
        lazygit
        codex
        pi
        television
        bat
        btop
        comically
        git
        cargo
        yazi
        tools
        nuke-default-packages
        user
        plugdev
        seni
        fonts
        compositor
        niri
        kitty
        keepassxc
        fuzzel
        noctalia
        vlc
        dolphin
        nautilus
        papers
        kde
        qt
        gtk
        zsh
        helium
        spotify-web
        roam-web
        mullvad
        tailscale
        moonlight
        qbittorrent
        scd
      ]);

    _module.args.host = host;

    nook.noctalia.lockscreen = {
      output = "eDP-1";
      logicalWidth = 2160;
    };

    compositor.niri.config = [
      {
        output = {
          args = ["eDP-1"];
          children = [
            {mode = "3456x2234";}
            {scale = 1.6;}
            {focus-at-startup = {};}
          ];
        };
      }
    ];
  };
}
