{pkgs, ...}: {
  environment.systemPackages = [pkgs.fzf];

  velum.programs.fzf = {
    ".fzfrc".render = theme:
      with theme.colors.withHashtag; ''
        --style=full
        --color=bg:${base00},bg+:${base01},fg:${base04},fg+:${base06},header:${base0D},hl:${base0D},hl+:${base0D},info:${base0A},marker:${base0C},pointer:${base0C},prompt:${base0A},spinner:${base0C}
      '';

    reload = [];
  };
}
