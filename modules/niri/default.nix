{...}: {
  flake.modules.nixos.niri = {pkgs, ...}: {
    imports = [
      ./_niri
    ];

    programs.niri.enable = true;

    environment.systemPackages = with pkgs; [
      phinger-cursors
      xwayland-satellite
    ];
  };
}
