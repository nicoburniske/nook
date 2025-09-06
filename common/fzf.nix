{...}: {
  programs.fzf = {
    enable = true;
    enableZshIntegration = false;
    defaultOptions = [
      "--style=full"
    ];
  };
}
