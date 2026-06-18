{...}: {
  flake.modules.nixos.roamWeb = {
    host,
    pkgs,
    ...
  }: let
    roamIcon = pkgs.fetchurl {
      url = "https://roamstatic.com/website/roam-logo-symbol-white-HS4V332B.svg";
      hash = "sha256-OKuc2QgcgG7grvI4xsVrKW6+t4NG5ma1kXTAIQtdR9Q=";
    };

    roamWeb = pkgs.runCommand "roam-web" {nativeBuildInputs = [pkgs.makeBinaryWrapper];} ''
      mkdir -p $out/bin
      makeBinaryWrapper ${pkgs.chromium}/bin/chromium $out/bin/roam-web \
        --add-flags "--user-data-dir=${host.homeDirectory}/.config/roam-web" \
        --add-flags "--app=https://ro.am/r/#"
    '';

    roamDesktop = pkgs.makeDesktopItem {
      name = "roam-web";
      desktopName = "Roam";
      genericName = "Virtual Office";
      exec = "${roamWeb}/bin/roam-web";
      icon = "${roamIcon}";
      categories = ["Office"];
    };
  in {
    environment.systemPackages = [
      roamWeb
      roamDesktop
    ];
  };
}
