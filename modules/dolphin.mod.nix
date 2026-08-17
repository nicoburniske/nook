{
  homeModules.dolphin = {
    lib,
    pkgs,
    ...
  }: {
    packages = [
      pkgs.kdePackages.dolphin
    ];
    file = {
      config."dolphinrc".value = lib.generators.toINI {} {
        General = {
          GlobalViewProps = true;
        };
      };
      data."dolphin/view_properties/global/.directory".value = lib.generators.toINI {} {
        Dolphin = {
          ViewMode = 1;
        };
      };
    };
  };
}
