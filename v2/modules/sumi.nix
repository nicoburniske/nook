{inputs, ...}: {
  flake.modules.nixos.sumi = {
    imports = [inputs.sumi.nixosModules.default];
  };

  flake.modules.darwin.sumi = {
    imports = [inputs.sumi.darwinModules.default];
  };
}
