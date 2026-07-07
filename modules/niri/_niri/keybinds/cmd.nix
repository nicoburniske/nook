{pkgs, ...}:
pkgs.writeNuScriptBin "niri-cmd" {
  source = ''
    source ${./cmd}/main.nu
  '';
  runtimeInputs = with pkgs; [
    ddcutil
    helium
    niri
    pipewire
    pulseaudio
    procps
    rofi
    systemd
    wlsunset
  ];
}
