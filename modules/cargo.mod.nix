{
  commonModules.cargo = {config, ...}: {
    environment.variables = {
      CARGO_HOME = "${config.lib.sumi.paths.data}/cargo";
      # block global installs with a read-only root
      CARGO_INSTALL_ROOT = "/nix/store";
    };

    sumi.dataFile = {
      "cargo/config.toml".value = ''
        [net]
        git-fetch-with-cli = true
      '';
    };
  };
}
