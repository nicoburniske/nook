{inputs, ...}: let
  codexModule = {pkgs, ...}: let
    codexPkgs = import inputs.nixpkgs-codex {
      inherit (pkgs.stdenv.hostPlatform) system;
    };
  in {
    environment.systemPackages = [codexPkgs.codex];
  };
in {
  flake.modules.nixos.codex = codexModule;
  flake.modules.darwin.codex = codexModule;
}
