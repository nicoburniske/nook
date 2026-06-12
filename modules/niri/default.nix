{...}: {
  flake.modules.nixos.niri = {pkgs, ...}: {
    imports = [
      ./_niri
      ./_niri/libinput-gestures.nix
      ./_niri/rofi.nix
    ];

    nixpkgs.overlays = [
      (final: prev: {
        niri = prev.niri.overrideAttrs (old: {
          patches =
            (old.patches or [])
            ++ [
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
