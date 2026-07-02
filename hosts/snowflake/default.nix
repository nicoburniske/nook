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
    modules = config.flake.modules.nixos;
  in {
    imports = with modules; [
      ./configuration.nix
      inputs.nix-ld.nixosModules.nix-ld
      plugdev
      sumi
      nushell
      fonts
      compositor
      niri
      lock
      greet
      kitty
      yazi
      fuzzel
      noctalia
      vlc
      dolphin
      kde
      qt
      gtk
      helix
      helium
      spotifyWeb
      roamWeb
      fzf
      ohMyPosh
      lazygit
      codex
      television
      zsh
      bat
      btop
      comically
      git
      cargo
      mullvad
    ];

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
