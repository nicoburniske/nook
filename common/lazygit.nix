{ config, ... }: let
  theme = if config.stylix.polarity == "light" then "--light" else "--dark";
  in {

  xdg.configFile."lazygit/config.yml".text = ''
    git:
      colorArg: always
      paging:
        pager: delta --true-color=never --paging=never --line-numbers ${theme}
  '';
}
