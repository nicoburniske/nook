{
  darwinModules.tailscale = {...}: {
    services.tailscale.enable = true;
  };

  nixosModules.tailscale = {...}: {
    services.tailscale = {
      enable = true;
      openFirewall = true;
    };
  };
}
