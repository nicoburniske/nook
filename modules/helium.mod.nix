{inputs, ...}: {
  inputs.helium-nix = {
    url = "github:schembriaiden/helium-browser-nix-flake";
    inputs.nixpkgs.follows = "nixpkgs";
  };

  nixosModules.helium = {pkgs, ...}: {
    nixpkgs.overlays = [
      (final: prev: {
        helium = let
          helium = inputs.helium-nix.packages.${final.stdenv.hostPlatform.system}.helium;
        in
          final.symlinkJoin {
            name = "helium";
            paths = [helium];
            nativeBuildInputs = [final.makeWrapper];
            postBuild = ''
              wrapProgram $out/bin/helium \
                --add-flags "--disable-features=WaylandWpColorManagerV1"
            '';
            meta = helium.meta or {};
          };
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
