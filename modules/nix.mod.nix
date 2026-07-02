{inputs, ...}: {
  flake.mod.common.nix = {
    nix.settings = (import "${inputs.self}/flake.nix").nixConfig;
  };
}
