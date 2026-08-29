{pkgs, ...}: {
  environment.systemPackages = with pkgs; [
    brightnessctl
    chromium
    pavucontrol
    obs-studio
    signal-desktop
  ];
}
