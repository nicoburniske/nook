{pkgs, ...}: {
  imports = [
    ./hyprland
    ./hyprlock.nix
    ./hyprpaper.nix
  ];

  environment.systemPackages = with pkgs; [
    hyprlock
    hyprpaper
    hyprshot
    phinger-cursors
  ];
}
