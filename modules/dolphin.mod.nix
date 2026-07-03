{
  mod.nixos.dolphin = {
    lib,
    pkgs,
    ...
  }: {
    environment.systemPackages = [
      pkgs.kdePackages.dolphin
    ];

    sumi.configFile."dolphinrc".value = lib.generators.toINI {} {
      General = {
        GlobalViewProps = true;
      };
    };

    sumi.dataFile."dolphin/view_properties/global/.directory".value = lib.generators.toINI {} {
      Dolphin = {
        ViewMode = 1;
      };
    };
  };
}
