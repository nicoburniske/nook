{...}: {
  flake.modules.nixos.hypr = {pkgs, ...}: {
    imports = [
      ./_hyprland
      ./_hyprlock.nix
      ./_hyprpaper.nix
      ./_greetd.nix
    ];

    environment.systemPackages = with pkgs; [
      hyprlock
      hyprpaper
      hyprshot
      phinger-cursors
    ];
  };
}
