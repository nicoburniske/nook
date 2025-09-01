{lib, config, ...}: {
  xdg.configFile = {
    "hammerspoon" = {
      source = config.lib.file.mkOutOfStoreSymlink ./config;
      recursive = true;
    };
  };

  home.activation.hammerspoonConfig = lib.hm.dag.entryAfter ["writeBoundary"] ''
    if [ ! -L "$HOME/.hammerspoon" ]; then
      rm -rf "$HOME/.hammerspoon"
      ln -s "$HOME/.config/hammerspoon" "$HOME/.hammerspoon"
    fi
  '';
}
