{...}: {
  flake.mod.common.cargo = {config, ...}: {
    environment.variables.CARGO_HOME = "${config.lib.sumi.paths.data}/cargo";

    sumi.dataFile = {
      "cargo/config.toml".value = ''
        [net]
        git-fetch-with-cli = true
      '';
    };
  };
}
