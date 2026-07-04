{
  nixosModules.chromium = {pkgs, ...}: {
    nixpkgs.allowedUnfreePackages = with pkgs; [
      chromium
      chromium.browser
      widevine-cdm
    ];

    nixpkgs.overlays = [
      (_: prev: {
        chromium = prev.chromium.override {
          enableWideVine = true;
        };
      })
    ];
  };
}
