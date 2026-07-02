{inputs, ...}: {
  flake-file.inputs.niri = {
    url = "github:niri-wm/niri";
    inputs.nixpkgs.follows = "nixpkgs";
  };

  flake.mod.nixos.niri = {pkgs, ...}: {
    imports = [
      ./_niri
      ./_niri/rofi.nix
    ];

    nixpkgs.overlays = [
      (final: prev: {
        niri = inputs.niri.packages.${final.stdenv.hostPlatform.system}.niri.overrideAttrs (old: {
          patches =
            (old.patches or [])
            ++ [
              ./patches/hdr.patch
              ./patches/workspace-switch-animate-property.patch
            ];
        });
      })
    ];

    hardware.i2c.enable = true;

    programs.niri.enable = true;

    environment.systemPackages = with pkgs; [
      phinger-cursors
      playerctl
      xwayland-satellite
    ];
  };
}
