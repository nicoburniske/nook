{ ... }: {
  xdg.configFile."lazygit/config.yml".text = ''
    git:
      colorArg: always
      paging:
        pager: delta --true-color=never --paging=never --line-numbers
  '';
}