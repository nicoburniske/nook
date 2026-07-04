{
  nixosModules.kanto-ora = {
    services.pipewire.wireplumber.extraConfig."51-kanto-ora-softvol" = {
      "monitor.alsa.rules" = [
        {
          matches = [
            {
              "device.vendor.id" = "0x8888";
              "device.product.name" = "ORA by Kanto";
            }
          ];
          actions.update-props."api.alsa.soft-mixer" = true;
        }
      ];
    };
  };
}
