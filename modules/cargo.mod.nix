{
  homeModules.cargo = {config, ...}: {
    environment.sessionVariables = {
      CARGO_HOME = "${config.path.data}/cargo";
      CARGO_INSTALL_ROOT = "/nix/store"; # block global installs with a read-only root
    };
    file.data."cargo/config.toml" = {
      value = ''
        [net]
        git-fetch-with-cli = true
      '';
    };
  };
}
