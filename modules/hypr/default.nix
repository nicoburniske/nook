{...}: {
  flake.modules.nixos.hypr = {pkgs, ...}: {
    imports = [
      ./_hyprland
      ./_hyprlock.nix
      ./_hyprpaper.nix
    ];

    environment.systemPackages = with pkgs; [
      hyprlock
      hyprpaper
      hyprshot
      phinger-cursors
    ];
  };
}
