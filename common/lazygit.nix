{config, pkgs, ...}: let
  theme =
    if config.stylix.polarity == "light"
    then "--light"
    else "--dark";
  colors = config.lib.stylix.colors;
  
  sendToHelix = cmd: pkgs.lib.concatStringsSep " && " [
    "kitty @ send-text --match 'state:overlay_parent' '\\x1b'"
    "kitty @ send-text --match 'state:overlay_parent' \"${cmd}\""
    "kitty @ send-text --match 'state:overlay_parent' '\\r'"
    "kitten @ close-window --match state:self"
  ];
in {
  programs.lazygit = {
    enable = true;
    settings = {
      os = {
        edit = sendToHelix ":open {{filename}}";
        editAtLine = sendToHelix ":open {{filename}}:{{line}}";
      };
      git = {
        colorArg = "always";
        paging = {
          pager = "delta --true-color=never --paging=never --line-numbers ${theme}";
        };
        # allow rewording
        overrideGpg = true;
      };

      gui = {
        theme = with colors.withHashtag; {
          selectedLineBgColor = [base01];
        };
        sidePanelWidth = 0.25;
      };
    };
  };
}
