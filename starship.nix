{ config, ... }:
{
  programs.starship = with config.lib.stylix.colors; {
    enable = true;
    enableTransience = true;
    settings = {
      format = "$directory$nix_shell$fill$git_branch$git_status$cmd_duration$line_break$character";
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
      git_status = {
        format = "[]($style)[$all_status$ahead_behind](bg:#${base01} fg:#${base09} bold)[ ]($style)";
        style = "bg:none fg:#${base01}";
        conflicted = "=";
        ahead = "[⇡\${count} ](fg:#${base0B} bg:#${base01}) ";
        behind = "[⇣\${count} ](fg:#${base08} bg:#${base01})";
        diverged = "↑\${ahead_count} ⇣\${behind_count} ";
        up_to_date = "[](fg:#${base0B} bg:#${base01})";
        untracked = "[?\${count} ](fg:#${base09} bg:#${base01}) ";
        stashed = "";
        modified = "[~\${count} ](fg:#${base09} bg:#${base01})";
        staged = "[+\${count} ](fg:#${base0B} bg:#${base01}) ";
        renamed = "[󰑕\${count} ](fg:#${base0A} bg:#${base01})";
        deleted = "[ \${count} ](fg:#${base08} bg:#${base01}) ";
      };
      cmd_duration = {
        min_time = 1;
        # duration & style ;
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
