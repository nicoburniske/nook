{...}: {
  flake.modules.nixos.niri = {pkgs, ...}: {
    imports = [
      ./_niri
      ./_niri/libinput-gestures.nix
    ];

    programs.niri = {
      enable = true;
      package = pkgs.niri.overrideAttrs (old: {
        patches =
          (old.patches or [])
          ++ [
            ./patches/workspace-switch-animate-property.patch
          ];
      });
    };

    environment.systemPackages = with pkgs; [
      phinger-cursors
      xwayland-satellite
    ];
  };
}
