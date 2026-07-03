{pkgs, ...}: {
  environment.systemPackages = with pkgs; [
    brightnessctl
    pavucontrol
    opencode
  ];
}
