{
  config,
  lib,
  pkgs,
  ...
}: {
  programs.ghostty = {
    enable = true;

    package = lib.mkIf pkgs.stdenv.isDarwin null;

    settings = {
      shell-integration-features = "no-cursor,no-title";
      gtk-titlebar = false;
      gtk-single-instance = true;
      adjust-cursor-thickness = 5;

      window-title-font-family = config.stylix.fonts.monospace.name;

      window-theme = "auto";
      window-decoration = "none";
      window-padding-balance = true;
      window-padding-x = 5;
      window-padding-y = 0;
      window-padding-color = "extend";

      macos-titlebar-style = "hidden";
      macos-option-as-alt = true;

      scrollback-limit = 104857600;

      keybind = [
        "shift+enter=text:\\n"
        "performable:ctrl+c=copy_to_clipboard"
        "performable:ctrl+v=paste_from_clipboard"
      ];
    };
  };
}
