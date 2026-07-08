{
  nixosModules.chromium = {pkgs, ...}: {
    nixpkgs = {
      allowedUnfreePackages = with pkgs; [
        chromium
        chromium.browser
        widevine-cdm
      ];
      overlays = [
        (_: prev: {
          chromium = prev.chromium.override {
            commandLineArgs = "--disable-features=WaylandWpColorManagerV1";
            enableWideVine = true;
          };
        })
      ];
    };
  };
}
