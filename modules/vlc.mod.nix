{...}: {
  flake.mod.nixos.vlc = {pkgs, ...}: {
    environment.systemPackages = [
      pkgs.vlc
    ];
  };
}
