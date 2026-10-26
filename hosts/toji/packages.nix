{
  inputs,
  pkgs,
  ...
}: let
  opencode = inputs.opencode-v2.packages.${pkgs.stdenv.hostPlatform.system}.opencode.overrideAttrs (oldAttrs: {
    node_modules = oldAttrs.node_modules.override {
      hash = "sha256-aVE36jaHfkvtzMyQv8ssMovGMHHgLKDk0GyxYeMOkVU=";
    };
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
