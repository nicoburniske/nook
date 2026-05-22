{
  config,
  inputs,
  ...
}: {
  configurations.darwin.fuji.module = {...}: let
    host = {
      name = "fuji";
      user = "nicoburniske";
      homeDirectory = "/Users/nicoburniske";
      flakeRoot = "/Users/nicoburniske/nook";
    };
    modules = config.flake.modules.darwin;
  in {
    imports = with modules; [
      ./configuration.nix
      ./packages.nix
      sumi
      fonts
      writeNuScriptBin
      kitty
      yazi
      helix
      fzf
      ohMyPosh
      lazygit
      television
      zsh
      bat
      btop
      comically
      git
      cargo
      hammerspoon
      inputs.nix-homebrew.darwinModules.nix-homebrew
      {
        nix-homebrew = {
          enable = true;
          enableRosetta = true;
          user = host.user;
          taps = {
            "homebrew/homebrew-core" = inputs.homebrew-core;
            "homebrew/homebrew-cask" = inputs.homebrew-cask;
          };
          mutableTaps = false;
        };
      }
    ];

    _module.args.host = host;

    nook.sumi.theme.transparency = {
      light = 1.0;
      dark = 1.0;
      darkOnLight = 1.0;
    };
  };
}
