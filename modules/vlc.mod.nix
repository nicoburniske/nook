{
  nixosModules.vlc = {pkgs, ...}: {
    environment.systemPackages = [
      pkgs.vlc
    ];
  };
}
