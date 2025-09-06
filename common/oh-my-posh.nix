{config, ...}: {
  programs.oh-my-posh = with config.lib.stylix.colors; {
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
              template = "  {{ .Path }}";
              properties = {
                style = "folder";
              };
            }
            {
              type = "git";
              style = "plain";
              foreground = "#${base08}";
              template = " <#${base0D}>git:(</>{{ .HEAD }}<#${base0D}>)</>"; 
              properties = {
                branch_icon = "";
              };
            }
            {
              type = "status";
              style = "plain";
              foreground = "#${base08}";
              template = " ✗";
            }
          ];
        }
      ];
      transient_prompt = {
        background = "transparent";
        foreground = "#${base05}";
        template = "❯ ";
      };
    };
  };
}
