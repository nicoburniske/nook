{ config, ... }: {
  xdg.configFile."scooter/config.toml".text = ''
    [editor_open]
    # Close the floating pane first, then open the file in helix
    command = "zellij action toggle-floating-panes && zellij action write 27 && zellij action write-chars ':open %file:%line' && zellij action write 13"
    exit = true

    [preview]
    syntax_highlighting = true
    syntax_highlighting_theme = "${
      if config.stylix.polarity == "dark"
      then "base16-ocean.dark"
      else "base16-ocean.light"
    }"
  '';
}