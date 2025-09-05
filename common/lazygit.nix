{ config, ... }: let
  theme = if config.stylix.polarity == "light" then "--light" else "--dark";
  colors = config.lib.stylix.colors;
  in {

  programs.lazygit = {
    enable = true;
    settings = {
      git = {
        colorArg = "always";
        paging = {
          pager =  "delta --true-color=never --paging=never --line-numbers ${theme}";
        };
      };
      gui.theme = with colors.withHashtag; {
        selectedLineBgColor = [ base01 ];
      };
    };
  };
}
