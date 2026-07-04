{
  nixosModules.shadps4 = {pkgs, ...}: let
    shadps4PkgExtractor = import ./extractor.nix {inherit pkgs;};
    save = pkgs.writeNuScriptBin "bbsave" {
      source = ./save.nu;
    };
  in {
    environment.systemPackages = [
      pkgs.shadps4-qtlauncher
      shadps4PkgExtractor
      save
    ];
  };
}
