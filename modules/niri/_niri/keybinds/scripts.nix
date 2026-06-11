{pkgs, ...}: {
  cmd = pkgs.writeNuScriptBin "niri-cmd" {
    source = ''
      source ${./cmd}/main.nu
    '';
    runtimeInputs = with pkgs; [
      helium
      niri
      pulseaudio
      rofi
    ];
  };
}
