{pkgs, ...}: {
  cmd = pkgs.writeNuScriptBin "niri-cmd" {
    source = ''
      source ${./cmd}/main.nu
    '';
    runtimeInputs = with pkgs; [
      ddcutil
      helium
      niri
      pipewire
      pulseaudio
      rofi
    ];
  };
}
