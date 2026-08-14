{
  nixosModules.sunshine = {pkgs, ...}: {
    services.sunshine = {
      enable = true;
      autoStart = true;
      capSysAdmin = true;
      package = pkgs.sunshine.overrideAttrs (oldAttrs: {
        patches =
          (oldAttrs.patches or [])
          ++ [
            (pkgs.fetchurl {
              url = "https://github.com/LizardByte/Sunshine/commit/86a253859e2eac62f41a2821804efa90ae8215c8.patch";
              hash = "sha256-hicZPJ0dHeiN10sWLeIP36VcQSZW5xAPnktrPq+8REQ=";
            })
          ];
      });
      settings.origin_web_ui_allowed = "wan";
    };

    networking.firewall.interfaces.tailscale0 = {
      allowedTCPPorts = [47984 47989 47990 48010];
      allowedUDPPorts = [47998 47999 48000 48002 48010];
    };
  };
}
