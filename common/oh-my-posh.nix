{
  programs.oh-my-posh = let
    base03 = "665c54";
    base05 = "d5c4a1";
    base08 = "fb4934";
    base0A = "fabd2f";
    base0B = "b8bb26";
    base0C = "8ec07c";
    base0D = "83a598";
    base0E = "d3869b";
  in {
    enable = true;
    enableZshIntegration = true;
    settings = {
      "$schema" = "https://raw.githubusercontent.com/JanDeDobbeleer/oh-my-posh/main/themes/schema.json";
      version = 3;
      final_space = true;
      blocks = [
        {
          type = "prompt";
          alignment = "left";
          segments = [
            {
              type = "path";
              style = "plain";
              foreground = "#${base0C}";
              template = "{{ .Path }}";
              properties = {
                style = "folder";
              };
            }
            {
              type = "git";
              style = "plain";
              foreground = "#${base08}";
              template = " <#${base0D}>(</>{{ .HEAD }}<#${base0D}>)</>";
              properties = {
                branch_icon = "";
              };
            }
            {
              type = "command";
              style = "plain";
              foreground = "#${base0E}";
              template = "{{ if .Output }} <#${base0B}></> {{ end }}";
              properties = {
                command = "[[ -n \"$IN_NIX_SHELL\" ]] && echo \"$IN_NIX_SHELL\"";
                shell = "bash";
              };
            }
            {
              type = "text";
              style = "plain";
              foreground = "#${base0A}";
              template = " ❯";
            }
          ];
        }
      ];
      transient_prompt = {
        background = "transparent";
        foreground = "#${base05}";
        template = "> ";
      };
    };
  };
}
