{config, ...}: {
  mod.nixos.roam-web = {
    host,
    pkgs,
    ...
  }: let
    roamIcon = pkgs.fetchurl {
      url = "https://roamstatic.com/website/roam-logo-symbol-white-HS4V332B.svg";
      hash = "sha256-OKuc2QgcgG7grvI4xsVrKW6+t4NG5ma1kXTAIQtdR9Q=";
    };
  in {
    imports = [config.flake.nixosModules.chromium];

    environment.systemPackages = pkgs.writeChromiumApp {
      name = "roam-web";
      url = "https://ro.am/r/#";
      desktopName = "Roam";
      icon = "${roamIcon}";
      categories = ["Office"];
      userDataDir = "${host.homeDirectory}/.config/roam-web";
    };
  };
}
