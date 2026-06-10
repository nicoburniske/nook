{
  inputs,
  pkgs,
}: {
  themeSwitch = import (inputs.self + "/common/theme-switch.nix") {inherit pkgs;};

  heliumProfile = pkgs.writeNuScriptBin "helium-profile" {
    source = ./helium-profile.nu;
    runtimeInputs = [pkgs.fuzzel pkgs.helium];
  };
  windowSwitch = pkgs.writeNuScriptBin "window-switch" {
    source = ./window-switch.nu;
    runtimeInputs = [pkgs.fuzzel pkgs.niri];
  };
  monitorOptions = pkgs.writeNuScriptBin "monitor-options" {
    source = ./monitor-options.nu;
    runtimeInputs = [pkgs.fuzzel pkgs.niri];
  };
}
