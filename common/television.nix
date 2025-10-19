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

  xdg.configFile."television/cable/text.toml".text = ''
    [metadata]
    name = "text"
    description = "A channel to find and select text from files"
    requirements = [ "rg", "bat",]

    [source]
    command = "rg . --no-heading --line-number --colors 'match:fg:white' --colors 'path:fg:blue' --color=always --smart-case"
    ansi = true
    output = "{strip_ansi|split:\\::..2}"

    [preview]
    command = "bat -n --color=always '{strip_ansi|split:\\::0}'"
    offset = "{strip_ansi|split:\\::1}"

    [ui.preview_panel]
    header = "{strip_ansi|split:\\::..2}"

  '';
}
