{ config, pkgs, lib, ... }:

let
  themeDefinitions = import ./stylix.nix {inherit pkgs lib;};
in {
  imports = [
    ./zellij.nix
    ./helix.nix
  ];
  # Home Manager needs a bit of information about you and the paths it should manage.
  home.username = "nico";
  home.homeDirectory = "/home/nico";

  # This value determines the Home Manager release that your configuration is
  # compatible with. This helps avoid breakage when a new Home Manager release
  # introduces backwards incompatible changes.
  home.stateVersion = "24.05";

  # Let Home Manager install and manage itself.
  programs.home-manager.enable = true;

  # Enable dconf for GNOME settings
  dconf.enable = true;

  # Enable fontconfig for font fallback configuration
  fonts.fontconfig.enable = true;

  # Stylix theming - apply default theme (Gruvbox Dark Hard)
  stylix = lib.mkMerge [
    (lib.mkDefault (builtins.head themeDefinitions.themes).stylix)
  ];

  programs.zoxide = {
    enable = true;
    enableBashIntegration = true;
    enableZshIntegration = true;
  };

  # Starship prompt configuration
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
        success_symbol = "[ ](#${base05} bold)";
        error_symbol = "[ ](#${base08} bold)";
        vicmd_symbol = "[ ](#${base03})";
      };
      directory = {
        format = "[]($style)[ ](bg:#${base01} fg:#${base05})[$path](bg:#${base01} fg:#${base05} bold)[ ]($style)";
        style = "bg:none fg:#${base01}";
        truncation_length = 3;
        truncate_to_repo = false;
      };
      git_branch = {
        format = "[]($style)[[ ](bg:#${base01} fg:#${base0A} bold)$branch](bg:#${base01} fg:#${base05} bold)[ ]($style)";
        style = "bg:none fg:#${base01}";
      };
      git_status = {
        format = "[]($style)[$all_status$ahead_behind](bg:#${base01} fg:#${base09} bold)[ ]($style)";
        style = "bg:none fg:#${base01}";
        conflicted = "=";
        ahead = "[⇡\${count} ](fg:#${base0B} bg:#${base01}) ";
        behind = "[⇣\${count} ](fg:#${base08} bg:#${base01})";
        diverged = "↑\${ahead_count} ⇣\${behind_count} ";
        up_to_date = "[](fg:#${base0B} bg:#${base01})";
        untracked = "[?\${count} ](fg:#${base09} bg:#${base01}) ";
        stashed = "";
        modified = "[~\${count} ](fg:#${base09} bg:#${base01})";
        staged = "[+\${count} ](fg:#${base0B} bg:#${base01}) ";
        renamed = "[󰑕\${count} ](fg:#${base0A} bg:#${base01})";
        deleted = "[ \${count} ](fg:#${base08} bg:#${base01}) ";
      };
      cmd_duration = {
        min_time = 1;
        format = "[]($style)[[ ](bg:#${base01} fg:#${base08} bold)$duration](bg:#${base01} fg:#${base05} bold)[]($style)";
        disabled = false;
        style = "bg:none fg:#${base01}";
      };
      nix_shell = {
        disabled = false;
        heuristic = false;
        format = "[]($style)[ ](bg:#${base01} fg:#${base05} bold)[]($style)";
        style = "bg:none fg:#${base01}";
        impure_msg = "";
        pure_msg = "";
        unknown_msg = "";
      };
    };
  };

  programs.git = {
    enable = true;
    userName = "Nico Burniske";
    userEmail = "nicoburniske@gmail.com";

    signing = {
      key = "~/.ssh/id_ed25519.pub";
      signByDefault = true;
    };

    aliases = {
      ca = "commit --amend --no-edit";
    };

    extraConfig = {
      gpg.format = "ssh";
      commit.gpgsign = true;
      push.autoSetupRemote = true;
      core = {
        pager = "delta";
        editor = "hx";
      };
      delta = {
        navigate = true;
        side-by-side = true;
        line-numbers = true;
        hyperlinks = true;
        features = "stylix";

        "stylix" = with config.lib.stylix.colors; {
          "${
            if config.stylix.polarity == "dark"
            then "dark"
            else "light"
          }" = true;

          file-style = "#${base05} bold";
          file-decoration-style = "#${base0A} ul";
          file-added-label = "[+]";
          file-copied-label = "[==]";
          file-modified-label = "[*]";
          file-removed-label = "[-]";
          file-renamed-label = "[->]";

          hunk-header-decoration-style = "#${base0D} box ul";
          hunk-header-file-style = "#${base0C}";
          hunk-header-line-number-style = "#${base0A}";
          hunk-header-style = "file line-number syntax";

          line-numbers-left-format = "{nm:>3}┊";
          line-numbers-right-format = "{np:>3}┊";
          line-numbers-left-style = "#${base03}";
          line-numbers-right-style = "#${base03}";
          line-numbers-minus-style = "#${base08} bold";
          line-numbers-plus-style = "#${base0B} bold";
          line-numbers-zero-style = "#${base04}";

          minus-style = "syntax #${base01}";
          minus-emph-style =
            "syntax "
            + (
              if config.stylix.polarity == "dark"
              then "#332222"
              else "#fff5f5"
            );
          plus-style = "syntax #${base01}";
          plus-emph-style =
            "syntax "
            + (
              if config.stylix.polarity == "dark"
              then "#223322"
              else "#f5fff5"
            );

          zero-style = "syntax";
          whitespace-error-style = "#${base08} reverse";

          commit-decoration-style = "#${base0A} box";
          commit-style = "#${base05} bold";

          blame-code-style = "syntax";
          blame-format = "{author:<18} ({commit:>7}) ┊{timestamp:^16}┊ ";
          blame-palette = "#${base00} #${base01} #${base02} #${base03}";
        };
      };
    };
  };

  programs.rofi = {
    enable = true;
  };

  # Yazi file manager configuration
  programs.yazi = {
    enable = true;

    settings = {
      mgr = {
        show_hidden = true;
      };

      opener = {
        edit = [
          {
            run = "hx \"$@\"";
            desc = "Edit in Helix";
            block = true;
          }
        ];

        video = [
          {
            run = "vlc \"$@\"";
            desc = "Open in VLC";
            orphan = true;
          }
        ];
      };

      open = {
        rules = [
          {
            mime = "text/*";
            use = "edit";
          }
          {
            mime = "application/json";
            use = "edit";
          }
          {
            mime = "application/javascript";
            use = "edit";
          }
          {
            mime = "application/toml";
            use = "edit";
          }
          {
            mime = "application/yaml";
            use = "edit";
          }
          {
            mime = "application/xml";
            use = "edit";
          }
          {
            mime = "video/*";
            use = "video";
          }
        ];
      };
    };
  };

  programs.fzf = {
    enable = true;
    enableZshIntegration = false;
    defaultOptions = [
      "--style=full"
    ];
  };

  programs.zsh = {
    enable = true;

    enableCompletion = true;
    autosuggestion = {
      enable = true;
    };
    syntaxHighlighting = {
      enable = true;
    };

    oh-my-zsh = {
      enable = true;
      plugins = [
        "gh"
        "zoxide"
        "bun"
        "docker"
        "docker-compose"
      ];
    };

    history = {
      size = 999999999;
      save = 999999999;
      path = "${config.home.homeDirectory}/.zsh_history";
      ignoreDups = true;
      share = false;
    };

    initContent = ''
      WORDCHARS=''${WORDCHARS//[\/]}

      bindkey '^I'   complete-word
      bindkey '^[[Z' autosuggest-accept

      export PATH=~/.cargo/bin:$PATH

      function yy() {
        local tmp="$(mktemp -t "yazi-cwd.XXXXXX")"
        yazi "$@" --cwd-file="$tmp"
        if cwd="$(cat -- "$tmp")" && [ -n "$cwd" ] && [ "$cwd" != "$PWD" ]; then
          cd -- "$cwd"
        fi
        rm -f -- "$tmp"
      }

      alias nix-shell='nix-shell --run $SHELL'
      nix() {
        if [[ $1 == "develop" ]]; then
          shift
          command nix develop -c $SHELL "$@"
        else
          command nix "$@"
        fi
      }
    '';

    shellAliases = {
      lg = "lazygit";
    };
  };
  
  wayland.windowManager.hyprland = {
    enable = true;
    # Use packages from NixOS module to avoid version conflicts
    package = null;
    portalPackage = null;
    
    # Import systemd environment variables for proper service integration
    systemd.variables = ["--all"];
    
    settings = {
      "$mod" = "alt";
      
      bind = [
        "$mod, Return, exec, ghostty"
        "$mod, Q, killactive"
        "$mod, M, exit"
        "$mod, F, togglefloating"
        "$mod, Space, exec, rofi -show drun"
        
        "$mod, H, movefocus, l"
        "$mod, L, movefocus, r"
        "$mod, K, movefocus, u"
        "$mod, J, movefocus, d"
        
        "$mod, 1, workspace, 1"
        "$mod, 2, workspace, 2"
        "$mod, 3, workspace, 3"
        "$mod, 4, workspace, 4"
        "$mod, 5, workspace, 5"
        "$mod, 6, workspace, 6"
        "$mod, 7, workspace, 7"
        "$mod, 8, workspace, 8"
        "$mod, 9, workspace, 9"
        "$mod, 0, workspace, 10"
        
        "$mod SHIFT, 1, movetoworkspace, 1"
        "$mod SHIFT, 2, movetoworkspace, 2"
        "$mod SHIFT, 3, movetoworkspace, 3"
        "$mod SHIFT, 4, movetoworkspace, 4"
        "$mod SHIFT, 5, movetoworkspace, 5"
        "$mod SHIFT, 6, movetoworkspace, 6"
        "$mod SHIFT, 7, movetoworkspace, 7"
        "$mod SHIFT, 8, movetoworkspace, 8"
        "$mod SHIFT, 9, movetoworkspace, 9"
        "$mod SHIFT, 0, movetoworkspace, 10"
      ];
      
      bindm = [
        "$mod, mouse:272, movewindow"
        "$mod, mouse:273, resizewindow"
      ];
      
      input = {
        kb_layout = "us";
        follow_mouse = 1;
        touchpad = {
          natural_scroll = true;
        };
        sensitivity = 0;
      };
      
      general = {
        gaps_in = 5;
        gaps_out = 20;
        border_size = 2;
        layout = "dwindle";
        resize_on_border = true;
      };
     
      animations = {
        enabled = true;
        bezier = "myBezier, 0.05, 0.9, 0.1, 1.05";
        animation = [
          "windows, 1, 7, myBezier"
          "windowsOut, 1, 7, default, popin 80%"
          "border, 1, 10, default"
          "borderangle, 1, 8, default"
          "fade, 1, 7, default"
          "workspaces, 1, 6, default"
        ];
      };
      
      dwindle = {
        pseudotile = true;
        preserve_split = true;
      };
      
      misc = {
        force_default_wallpaper = -1;
      };
    };
  };

  programs.ghostty = {
    enable = true;

    settings = {
      shell-integration-features = "no-cursor,no-title";
      gtk-titlebar = false;
      gtk-single-instance = true;
      adjust-cursor-thickness = 5;

      font-size = 13;

      window-theme = "auto";
      window-decoration = "none";
      window-padding-balance = true;
      window-padding-x = 5;
      window-padding-y = 0;
      window-padding-color = "extend";

      scrollback-limit = 104857600;

      keybind = [
        "shift+enter=text:\\n"
      ];
    };
  };

  # Cargo configuration
  home.file.".cargo/config.toml".text = ''
    [net]
    git-fetch-with-cli = true
  '';

  # Lazygit configuration
  xdg.configFile."lazygit/config.yml".text = ''
    git:
      colorArg: always
      paging:
        pager: delta --true-color=never --paging=never --line-numbers
  '';

  # Scooter configuration  
  xdg.configFile."scooter/config.toml".text = ''
    [editor_open]
    # Close the floating pane first, then open the file in helix
    command = "zellij action toggle-floating-panes && zellij action write 27 && zellij action write-chars ':open %file:%line' && zellij action write 13"
    exit = true

    [preview]
    syntax_highlighting = true
    syntax_highlighting_theme = "${
      if config.stylix.polarity == "dark"
      then "base16-ocean.dark"
      else "base16-ocean.light"
    }"
  '';

  home.packages = with pkgs; [
    nerd-fonts.jetbrains-mono
    
    opencode
    
    ripgrep
    lazygit
    delta
    btop
    tokei
    nil
    marksman
    bun
    ffmpeg
    lua-language-server
    rustup
    scooter
    cmake
    
    (writeShellScriptBin "zj" ''
      #!/usr/bin/env bash
      sessions=$(zellij list-sessions -n 2>/dev/null | grep -v "EXITED")

      if [ -z "$sessions" ]; then
        echo "No active sessions"
        exit 1
      fi

      selected=$(echo "$sessions" | fzf \
        --header="Switch Session" \
        --height=100% \
        --layout=reverse)

      if [ -n "$selected" ]; then
        session_name=$(echo "$selected" | awk '{print $1}')
        zellij attach "$session_name"
      fi
    '')
  ];
}
