{...}: let
  cargoModule = {config, ...}: {
    environment.variables.CARGO_HOME = "${config.lib.sumi.paths.data}/cargo";

    sumi.dataFile = {
      "cargo/config.toml".text = ''
        [net]
        git-fetch-with-cli = true
      '';
    };
  };
in {
  flake.modules.nixos.cargo = cargoModule;
  flake.modules.darwin.cargo = cargoModule;
}
