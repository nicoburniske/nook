{...}: {
  programs.television = {
    enable = true;
  };
  xdg.configFile."television/cable/files.toml".text = ''
    [metadata]
    name = "files"
    description = "A channel to select files and directories"
    requirements = ["fd", "bat"]

    [source]
    command = "fd -t f"

    [preview]
    command = "bat -n --color=always '{}'"
  '';
}
