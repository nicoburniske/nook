{
  homeModules.oh-my-posh = {
    config,
    pkgs,
    ...
  }: {
    packages = [pkgs.oh-my-posh];

    zsh.promptInit = pkgs.lib.mkAfter ''
      eval "$(${pkgs.oh-my-posh}/bin/oh-my-posh init zsh --config "${config.path.config}/ohmyposh/config.json")"
    '';

    file.config."ohmyposh/config.json" = {
      facet = "theme";
      value = facets: let
        theme = facets.theme.value;
      in
        builtins.toJSON {
          "$schema" = "https://raw.githubusercontent.com/JanDeDobbeleer/oh-my-posh/main/themes/schema.json";
          version = 3;
          final_space = true;
          blocks = [
            {
              type = "prompt";
              alignment = "left";
              newline = true;
              segments = with theme.colors.withHashtag; [
                {
                  type = "path";
                  style = "plain";
                  foreground = base0C;
                  template = "{{ .Path }}";
                  properties = {
                    style = "folder";
                  };
                }
                {
                  type = "git";
                  style = "plain";
                  foreground = base08;
                  template = " <${base0D}>(</>{{ .HEAD }}<${base0D}>)</>";
                  properties = {
                    branch_icon = "";
                  };
                }
                {
                  type = "nix-shell";
                  style = "plain";
                  foreground = base0E;
                  template = "{{ if ne .Type \"unknown\" }} <${base0B}></> {{ end }}";
                }
              ];
            }
            {
              type = "prompt";
              alignment = "left";
              newline = true;
              segments = with theme.colors.withHashtag; [
                {
                  type = "text";
                  style = "plain";
                  foreground_templates = [
                    "{{ if gt .Code 0 }}${base08}{{ end }}"
                    "{{ if eq .Code 0 }}${base0A}{{ end }}"
                  ];
                  template = "❯";
                }
              ];
            }
          ];
          transient_prompt = {
            background = "transparent";
            foreground_templates = with theme.colors.withHashtag; [
              "{{ if gt .Code 0 }}${base08}{{ end }}"
              "{{ if eq .Code 0 }}${base0A}{{ end }}"
            ];
            newline = true;
            template = "❯ ";
          };
        };
    };
  };
}
