{lib, ...}: {
  xdg.configFile = {
    "hammerspoon" = {
      source = lib.cleanSourceWith {
        src = lib.cleanSource ./config/.;
      };
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
