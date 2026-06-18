{
  config,
  inputs,
  ...
}: {
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
      writeNuScriptBin
      compositor
      niri
      awww
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

    programs.nix-ld.dev.enable = true;
    programs.noctalia-shell.enable = true;
  };
}
