{...}: let
  vlcModule = {pkgs, ...}: {
    environment.systemPackages = [
      pkgs.vlc
    ];
  };
in {
  flake.modules.nixos.vlc = vlcModule;
}
