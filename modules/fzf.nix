{...}: let
  fzfModule = {
    config,
    pkgs,
    ...
  }: {
    environment.systemPackages = [pkgs.fzf];
    environment.variables.FZF_DEFAULT_OPTS_FILE = "${config.lib.sumi.paths.config}/fzf/fzfrc";

    sumi.configFile."fzf/fzfrc" = {
      watch = ["theme"];
      value = ctx: let
        theme = ctx.values.theme;
        colors = with theme.colors.withHashtag; {
          bg = base00;
          "bg+" = base01;
          fg = base04;
          "fg+" = base06;
          header = base0D;
          hl = base0D;
          "hl+" = base0D;
          info = base0A;
          marker = base0C;
          pointer = base0C;
          prompt = base0A;
          spinner = base0C;
        };
        colorOption = builtins.concatStringsSep "," (
          pkgs.lib.mapAttrsToList (name: value: "${name}:${value}") colors
        );
      in ''
        --style=full
        --color=${colorOption}
      '';
    };
  };
in {
  flake.modules.nixos.fzf = fzfModule;
  flake.modules.darwin.fzf = fzfModule;
}
