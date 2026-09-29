{inputs, pkgs, ...}: let
  opencode = inputs.opencode-v2.packages.${pkgs.stdenv.hostPlatform.system}.opencode.overrideAttrs (_: {
    postInstall = "";
  });
in {
  environment.systemPackages = with pkgs; [
    brightnessctl
    chromium
    pavucontrol
    obs-studio
    opencode
    signal-desktop
  ];
}
