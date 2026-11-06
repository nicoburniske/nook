{pkgs, ...}: {
  environment.systemPackages = with pkgs; [
    brightnessctl
    chromium
    pavucontrol
    obs-studio
    opencode
    signal-desktop
  ];
}
