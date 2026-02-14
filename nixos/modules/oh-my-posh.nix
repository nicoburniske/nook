{pkgs, ...}: {
  environment.systemPackages = [pkgs.oh-my-posh];

  programs.zsh.interactiveShellInit = ''
    eval "$(${pkgs.oh-my-posh}/bin/oh-my-posh init zsh --config "$HOME/.config/ohmyposh/config.json")"
  '';

  velum.programs.oh-my-posh = {
    "ohmyposh/config.json".render = theme:
      builtins.toJSON {
        "$schema" = "https://raw.githubusercontent.com/JanDeDobbeleer/oh-my-posh/main/themes/schema.json";
        version = 3;
        final_space = true;
        blocks = [
          {
            type = "prompt";
            alignment = "left";
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
                type = "command";
                style = "plain";
                foreground = base0E;
                template = "{{ if .Output }} <${base0B}></> {{ end }}";
                properties = {
                  command = "[[ -n \"$IN_NIX_SHELL\" ]] && echo \"$IN_NIX_SHELL\"";
                  shell = "bash";
                };
              }
              {
                type = "text";
                style = "plain";
                foreground = base0A;
                template = " ❯";
              }
            ];
          }
        ];
        transient_prompt = {
          background = "transparent";
          foreground = theme.colors.withHashtag.base05;
          template = "> ";
        };
      };

    reload = [];
  };
}
