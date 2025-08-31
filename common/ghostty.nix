{ ... }: {
  programs.ghostty = {
    enable = true;

    settings = {
      shell-integration-features = "no-cursor,no-title";
      gtk-titlebar = false;
      gtk-single-instance = true;
      adjust-cursor-thickness = 5;

      window-theme = "auto";
      window-decoration = "none";
      window-padding-balance = true;
      window-padding-x = 5;
      window-padding-y = 0;
      window-padding-color = "extend";

      scrollback-limit = 104857600;

      keybind = [
        "shift+enter=text:\\n"
      ];
    };
  };
}