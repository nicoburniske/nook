{inputs, ...}: {
  flake.modules.nixos.helium = {pkgs, ...}: {
    environment.systemPackages = [
      inputs.helium-nix.packages.${pkgs.stdenv.hostPlatform.system}.default
    ];
  };
}
