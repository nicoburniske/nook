{
  commonModules.fzf = {
    config,
    pkgs,
    ...
  }: {
    environment = {
      systemPackages = [pkgs.fzf];
      variables.FZF_DEFAULT_OPTS_FILE = "${config.lib.sumi.paths.config}/fzf/fzfrc";
    };

    nook.zsh.promptInit = ''
      source "${pkgs.fzf}/share/fzf/key-bindings.zsh"
    '';

    sumi.configFile."fzf/fzfrc" = {
      watch = "theme";
      value = ctx: let
        theme = ctx.value;
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
        colorOption =
          colors
          |> pkgs.lib.mapAttrsToList (name: value: "${name}:${value}")
          |> builtins.concatStringsSep ",";
      in ''
        --style=full
        --color=${colorOption}
      '';
    };
  };
}
