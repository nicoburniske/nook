{...}: {
  sumi.programs.cargo = {
    ".cargo/config.toml".text = ''
      [net]
      git-fetch-with-cli = true
    '';

    reload = [];
  };
}
