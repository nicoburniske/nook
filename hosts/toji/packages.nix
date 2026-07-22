{pkgs, ...}: {
  environment.systemPackages = with pkgs; [
    brightnessctl
    chromium
    pavucontrol
  ];
}
