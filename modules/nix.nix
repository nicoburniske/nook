{inputs, ...}: let
  nixModule = {
    nix.settings = (import "${inputs.self}/flake.nix").nixConfig;
  };
in {
  flake.modules.nixos.nix = nixModule;
  flake.modules.darwin.nix = nixModule;
}
