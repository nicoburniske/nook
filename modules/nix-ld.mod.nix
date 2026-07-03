{...}: {
  flake.mod.nixos.nixLd = {
    programs.nix-ld.enable = true;
  };
}
