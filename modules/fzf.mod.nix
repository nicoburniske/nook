{
  homeModules.fzf = {
    config,
    pkgs,
    ...
  }: {
    packages = [pkgs.fzf];
    environment.sessionVariables.FZF_DEFAULT_OPTS_FILE = "${config.path.config}/fzf/fzfrc";

    zsh.promptInit = ''
      source "${pkgs.fzf}/share/fzf/key-bindings.zsh"
    '';

    file.config."fzf/fzfrc" = {
      facet = "theme";
      value = facets: let
        theme = facets.theme.value;
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
