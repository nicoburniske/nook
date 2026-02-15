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

    systemd.user.targets.hyprland-session = {
      description = "Hyprland compositor session";
      documentation = ["man:systemd.special(7)"];
      bindsTo = ["graphical-session.target"];
      wants = ["graphical-session-pre.target"];
      after = ["graphical-session-pre.target"];
    };
  };
}
