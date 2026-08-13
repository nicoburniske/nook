{
  nixosModules.tailscale = {...}: {
    services.tailscale = {
      enable = true;
      openFirewall = true;
    };
  };
}
