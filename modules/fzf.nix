{...}: let
  fzfModule = {
    config,
    pkgs,
    ...
  }: {
    environment.systemPackages = [pkgs.fzf];
    environment.variables.FZF_DEFAULT_OPTS_FILE = "${config.lib.sumi.paths.config}/fzf/fzfrc";

    sumi.configFile."fzf/fzfrc" = {
      dependsOn = ["theme"];
      render = ctx: let
        theme = ctx.values.theme;
      in
        with theme.colors.withHashtag; ''
          --style=full
          --color=bg:${base00},bg+:${base01},fg:${base04},fg+:${base06},header:${base0D},hl:${base0D},hl+:${base0D},info:${base0A},marker:${base0C},pointer:${base0C},prompt:${base0A},spinner:${base0C}
        '';
    };
  };
in {
  flake.modules.nixos.fzf = fzfModule;
  flake.modules.darwin.fzf = fzfModule;
}
