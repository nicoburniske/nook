{pkgs, ...}: {
  environment.systemPackages = with pkgs; [
    brightnessctl
    obs-studio
    sparrow
    snapshot
    readest
    pavucontrol
    asahi-bless
  ];
}
