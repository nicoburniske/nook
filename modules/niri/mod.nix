{inputs, ...}: {
  inputs = {
    niri = {
      url = "github:dividebysandwich/niri/main";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    smithay = {
      url = "github:dividebysandwich/smithay/master";
      flake = false;
    };
  };
  nixosModules.niri = {pkgs, ...}: {
    imports = [
      ./_niri
    ];

    nixpkgs.overlays = [
      (final: prev: {
        niri = inputs.niri.packages.${final.stdenv.hostPlatform.system}.niri.overrideAttrs (old: {
          postPatch =
            (old.postPatch or "")
            + ''
              ln -s ${inputs.smithay} ../smithay
            '';

          patches =
            (old.patches or [])
            ++ [
              ./patches/workspace-switch-animate-property.patch
              ./patches/hdr-sdr-controls.patch
            ];
        });
      })
    ];

    hardware.i2c.enable = true;

    programs.niri.enable = true;

    environment.systemPackages = with pkgs; [
      phinger-cursors
      playerctl
      wl-clipboard
      xwayland-satellite
    ];
  };
}
