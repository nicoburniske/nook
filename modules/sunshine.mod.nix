{
  nixosModules.sunshine = {...}: {
    services.sunshine = {
      enable = true;
      autoStart = true;
      capSysAdmin = true;
      settings.origin_web_ui_allowed = "wan";
    };

    networking.firewall.interfaces.tailscale0 = {
      allowedTCPPorts = [47984 47989 47990 48010];
      allowedUDPPorts = [47998 47999 48000 48002 48010];
    };
  };
}
