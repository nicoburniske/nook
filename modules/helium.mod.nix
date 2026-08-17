{inputs, ...}: {
  inputs.helium-nix = {
    url = "github:schembriaiden/helium-browser-nix-flake";
    inputs = {
      nixpkgs.follows = "nixpkgs";
      nixpkgs-darwin.follows = "nixpkgs";
      utils.inputs.systems.follows = "systems";
    };
  };
  commonModules.helium = {pkgs, ...}: {
    nixpkgs.overlays = [
      (final: _: {
        helium = inputs.helium-nix.packages.${final.stdenv.hostPlatform.system}.helium;
      })
    ];
  };
  homeModules.helium = {
    lib,
    pkgs,
    ...
  }: {
    config = lib.mkMerge [
      {packages = [pkgs.helium];}
      (lib.mkIf pkgs.stdenv.isLinux {
        xdg.mime.defaultApplications = {
          "application/xhtml+xml" = ["helium.desktop"];
          "text/html" = ["helium.desktop"];
          "text/xml" = ["helium.desktop"];
          "x-scheme-handler/http" = ["helium.desktop"];
          "x-scheme-handler/https" = ["helium.desktop"];
        };
      })
    ];
  };
  nixosModules.helium = {lib, ...}: {
    nixpkgs.overlays = lib.mkAfter [
      (final: prev: {
        helium = final.symlinkJoin {
          name = "helium";
          paths = [prev.helium];
          nativeBuildInputs = [final.makeWrapper];
          postBuild = ''
            wrapProgram $out/bin/helium \
              --add-flags "--disable-features=WaylandWpColorManagerV1"
          '';
          meta = prev.helium.meta or {};
        };
      })
    ];
  };
}
