{inputs, ...}: {
  inputs.helium-nix = {
    url = "github:schembriaiden/helium-browser-nix-flake";
    inputs.nixpkgs.follows = "nixpkgs";
  };

  flake.mod.nixos.helium = {pkgs, ...}: {
    nixpkgs.overlays = [
      (final: prev: {
        helium = inputs.helium-nix.packages.${final.stdenv.hostPlatform.system}.helium;
      })
    ];

    environment.systemPackages = [
      pkgs.helium
    ];
  };
}
