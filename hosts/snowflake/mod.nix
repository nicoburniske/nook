{
  config,
  inputs,
  ...
}: {
  flake-file.inputs = {
    apple-silicon = {
      url = "github:nix-community/nixos-apple-silicon";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nix-ld = {
      url = "github:Mic92/nix-ld";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  configurations.nixos.snowflake.module = {...}: let
    host = {
      name = "snowflake";
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
        inputs.nix-ld.nixosModules.nix-ld
      ]
      ++ (with common; [
        nix
        nushell
        helix
        fzf
        ohMyPosh
        lazygit
        codex
        television
        bat
        btop
        comically
        git
        cargo
        yazi
      ])
      ++ (with modules; [
        plugdev
        sumi
        fonts
        compositor
        niri
        lock
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
        spotifyWeb
        roamWeb
        mullvad
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

    programs.nix-ld.dev.enable = true;
    programs.noctalia.enable = true;
  };
}
