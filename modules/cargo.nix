{...}: let
  cargoModule = {
    sumi.file = {
      ".cargo/config.toml".text = ''
        [net]
        git-fetch-with-cli = true
      '';
    };
  };
in {
  flake.modules.nixos.cargo = cargoModule;
  flake.modules.darwin.cargo = cargoModule;
}
