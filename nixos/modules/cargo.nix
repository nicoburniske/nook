{...}: {
  sumi.file = {
    ".cargo/config.toml".text = ''
      [net]
      git-fetch-with-cli = true
    '';
  };

  sumi.program.cargo.reload = [];
}
