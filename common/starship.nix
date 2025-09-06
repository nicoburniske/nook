{config, ...}: {
  programs.starship = with config.lib.stylix.colors; {
    enable = false;
    enableTransience = true;
    settings = {
      format = "$directory$nix_shell$fill$git_branch$cmd_duration$line_break$character";
      add_newline = false;
      c.disabled = true;

      fill = {
        symbol = " ";
      };
      conda = {
        format = " [ $symbol$environment ] (dimmed green) ";
      };
      character = {
        success_symbol = "[ ](#${base05} bold)";
        error_symbol = "[ ](#${base08} bold)";
        vicmd_symbol = "[ ](#${base03})";
      };
      directory = {
        format = "[]($style)[ ](bg:#${base01} fg:#${base05})[$path](bg:#${base01} fg:#${base05} bold)[ ]($style)";
        style = "bg:none fg:#${base01}";
        truncation_length = 3;
        truncate_to_repo = false;
      };
      git_branch = {
        format = "[]($style)[[ ](bg:#${base01} fg:#${base0A} bold)$branch](bg:#${base01} fg:#${base05} bold)[ ]($style)";
        style = "bg:none fg:#${base01}";
      };
      cmd_duration = {
        min_time = 1;
        format = "[]($style)[[ ](bg:#${base01} fg:#${base08} bold)$duration](bg:#${base01} fg:#${base05} bold)[]($style)";
        disabled = false;
        style = "bg:none fg:#${base01}";
      };
      nix_shell = {
        disabled = false;
        heuristic = false;
        format = "[]($style)[ ](bg:#${base01} fg:#${base05} bold)[]($style)";
        style = "bg:none fg:#${base01}";
        impure_msg = "";
        pure_msg = "";
        unknown_msg = "";
      };
    };
  };
}
