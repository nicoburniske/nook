{inputs, ...}: {
  flake.modules.nixos.helium = {pkgs, ...}: {
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
