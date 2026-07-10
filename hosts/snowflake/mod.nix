{config, ...}: {
  inputs.apple-silicon = {
    url = "github:nix-community/nixos-apple-silicon";
    inputs.nixpkgs.follows = "nixpkgs";
  };

  configurations.nixos.snowflake.module = {...}: let
    host = {
      name = "snowflake";
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
        sumi
        xdg
        fonts
        compositor
        niri
        greet
        kitty
        keepassxc
        fuzzel
        noctalia
        vlc
        dolphin
        nautilus
        kde
        qt
        gtk
        zsh
        helium
        spotify-web
        roam-web
        mullvad
        qbittorrent
      ]);

    _module.args.host = host;

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
