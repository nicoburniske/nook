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
            enableWideVine = true;
          };
        })
      ];
    };
  };
}
