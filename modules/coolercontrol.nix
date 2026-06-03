{...}: {
  flake.modules.nixos.coolercontrol = {...}: {
    boot.kernelModules = ["nct6775"];

    programs.coolercontrol.enable = true;
  };
}
