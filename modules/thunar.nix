{...}: let
  thunarModule = {
    lib,
    pkgs,
    ...
  }: {
    environment.systemPackages = [pkgs.thunar];

    sumi.configFile."Thunar/thunarrc".text = lib.generators.toINI {} {
      Configuration = {
        DefaultView = "ThunarDetailsView";
        LastView = "ThunarDetailsView";
      };
    };
  };
in {
  flake.modules.nixos.thunar = thunarModule;
}
