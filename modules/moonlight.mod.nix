{
  nixosModules.moonlight = {pkgs, ...}: {
    environment.systemPackages = [pkgs.moonlight-qt];
  };
}
