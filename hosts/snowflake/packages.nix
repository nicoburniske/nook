{pkgs, ...}: {
  environment.systemPackages = with pkgs; [
    brightnessctl
    jmtpfs
    obs-studio
    sparrow
    snapshot
    readest
    pavucontrol
    asahi-bless
  ];
}
