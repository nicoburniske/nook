{
  nixosModules.mullvad = {pkgs, ...}: {
    services.mullvad-vpn = {
      enable = true;
      package = pkgs.mullvad-vpn;
    };
  };
}
