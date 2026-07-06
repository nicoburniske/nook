{inputs, ...}: {
  inputs.helium-nix = {
    url = "github:schembriaiden/helium-browser-nix-flake";
    inputs.nixpkgs.follows = "nixpkgs";
  };

  nixosModules.helium = {pkgs, ...}: {
    nixpkgs.overlays = [
      (final: prev: {
        helium = inputs.helium-nix.packages.${final.stdenv.hostPlatform.system}.helium;
      })
    ];

    sumi.xdg.mime.defaultApplications = {
      "application/xhtml+xml" = ["helium.desktop"];
      "text/html" = ["helium.desktop"];
      "text/xml" = ["helium.desktop"];
      "x-scheme-handler/http" = ["helium.desktop"];
      "x-scheme-handler/https" = ["helium.desktop"];
    };

    environment.systemPackages = [
      pkgs.helium
    ];
  };
}
