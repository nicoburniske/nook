{...}: let
  codexModule = {pkgs, ...}: {
    environment.systemPackages = [pkgs.codex];
  };
in {
  flake.modules.nixos.codex = codexModule;
  flake.modules.darwin.codex = codexModule;
}
