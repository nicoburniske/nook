{ config, pkgs, lib, ... }:

let
  themeDefinitions = import ./stylix.nix {inherit pkgs lib;};
in {
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

  # Stylix theming - apply default theme (Gruvbox Dark Hard)
  stylix = lib.mkMerge [
    (lib.mkDefault (builtins.head themeDefinitions.themes).stylix)
  ];

  # Zoxide shell integration (fixing the z command issue)
  programs.zoxide = {
    enable = true;
    enableBashIntegration = true;
    enableZshIntegration = true;
  };

  # Zellij terminal multiplexer configuration
  xdg.configFile."zellij/home_manager_config.kdl" = {
    text = with config.lib.stylix.colors.withHashtag; ''
      default_mode "locked"
      pane_frames false

      keybinds {
        shared {
          unbind "Ctrl g";
          bind "Ctrl Space" {
            SwitchToMode "locked";
          }
        }

        locked {
          bind "Ctrl Space" {
            SwitchToMode "normal";
          }
        }

        normal {
          bind "Ctrl h" {
            MoveFocusOrTab "Left";
          }
          bind "Ctrl l" {
            MoveFocusOrTab "Right";
          }
          bind "Ctrl j" {
            MoveFocus "Down";
          }
          bind "Ctrl k" {
            MoveFocus "Up";
          }

          bind "Ctrl a" {
            SwitchToMode "locked";
            LaunchOrFocusPlugin "session-manager" {
              floating true;
              move_to_focused_tab true;
            }
          }
        }
      }

      plugins {
        compact-bar location="zellij:compact-bar" {
            tooltip "Ctrl /";
          }
      }

      themes {
        default {
          text_unselected {
            base "${base05}"
            background "${base01}"
            emphasis_0 "${base09}"
            emphasis_1 "${base0C}"
            emphasis_2 "${base0B}"
            emphasis_3 "${base0F}"
          }
          text_selected {
            base "${base05}"
            background "${base04}"
            emphasis_0 "${base09}"
            emphasis_1 "${base0C}"
            emphasis_2 "${base0B}"
            emphasis_3 "${base0F}"
          }
          ribbon_selected {
            base "${base01}"
            background "${base0E}"
            emphasis_0 "${base08}"
            emphasis_1 "${base09}"
            emphasis_2 "${base0F}"
            emphasis_3 "${base0D}"
          }
          ribbon_unselected {
            base "${base01}"
            background "${base04}"
            emphasis_0 "${base08}"
            emphasis_1 "${base05}"
            emphasis_2 "${base0D}"
            emphasis_3 "${base0F}"
          }
          table_title {
            base "${base0E}"
            background "${base00}"
            emphasis_0 "${base09}"
            emphasis_1 "${base0C}"
            emphasis_2 "${base0B}"
            emphasis_3 "${base0F}"
          }
          table_cell_selected {
            base "${base05}"
            background "${base04}"
            emphasis_0 "${base09}"
            emphasis_1 "${base0C}"
            emphasis_2 "${base0B}"
            emphasis_3 "${base0F}"
          }
          table_cell_unselected {
            base "${base05}"
            background "${base01}"
            emphasis_0 "${base09}"
            emphasis_1 "${base0C}"
            emphasis_2 "${base0B}"
            emphasis_3 "${base0F}"
          }
          list_selected {
            base "${base05}"
            background "${base02}"
            emphasis_0 "${base09}"
            emphasis_1 "${base0C}"
            emphasis_2 "${base0B}"
            emphasis_3 "${base0F}"
          }
          list_unselected {
            base "${base05}"
            background "${base01}"
            emphasis_0 "${base09}"
            emphasis_1 "${base0C}"
            emphasis_2 "${base0B}"
            emphasis_3 "${base0F}"
          }
          frame_selected {
            base "${base0E}"
            background "${base00}"
            emphasis_0 "${base09}"
            emphasis_1 "${base0C}"
            emphasis_2 "${base0F}"
            emphasis_3 "${base00}"
          }
          frame_highlight {
            base "${base08}"
            background "${base00}"
            emphasis_0 "${base0F}"
            emphasis_1 "${base09}"
            emphasis_2 "${base09}"
            emphasis_3 "${base09}"
          }
          exit_code_success {
            base "${base0B}"
            background "${base00}"
            emphasis_0 "${base0C}"
            emphasis_1 "${base01}"
            emphasis_2 "${base0F}"
            emphasis_3 "${base0D}"
          }
          exit_code_error {
            base "${base08}"
            background "${base00}"
            emphasis_0 "${base0A}"
            emphasis_1 "${base00}"
            emphasis_2 "${base00}"
            emphasis_3 "${base00}"
          }
          multiplayer_user_colors {
            player_1 "${base0F}"
            player_2 "${base0D}"
            player_3 "${base00}"
            player_4 "${base0A}"
            player_5 "${base0C}"
            player_6 "${base00}"
            player_7 "${base08}"
            player_8 "${base00}"
            player_9 "${base00}"
            player_10 "${base00}"
          }
        }
      }
    '';
  };

  xdg.configFile."zellij/layouts/default.kdl" = {
    text =''
      layout {
          pane
          pane size=1 borderless=true {
              plugin location="compact-bar"
          }
      }
    '';
  };

  # Always ensure config.kdl is a real file (not symlink) for runtime reloading
  home.activation.zellijConfig = lib.hm.dag.entryAfter ["writeBoundary"] ''
    if [ -f ${config.xdg.configHome}/zellij/home_manager_config.kdl ]; then
      rm -f ${config.xdg.configHome}/zellij/config.kdl
      cp ${config.xdg.configHome}/zellij/home_manager_config.kdl ${config.xdg.configHome}/zellij/config.kdl
      chmod u+w ${config.xdg.configHome}/zellij/config.kdl
    fi
  '';

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

  # Basic git configuration (simplified from macOS config)
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

  # Basic helix configuration (simplified from macOS config)
  programs.helix = {
    enable = true;

    settings = {
      editor = {
        bufferline = "always";
        cursorline = true;
        color-modes = true;
        end-of-line-diagnostics = "hint";
        popup-border = "all";

        cursor-shape = {
          insert = "bar";
        };

        file-picker = {
          hidden = false;
        };

        lsp = {
          display-messages = true;
          goto-reference-include-declaration = false;
        };

        inline-diagnostics = {
          cursor-line = "info";
        };
      };

      keys.normal = {
        X = "extend_line_above";

        "C-g" = ":sh zellij run -c -f -n git -x 5%% -y 5%% --width 90%% --height 90%% -- lazygit";
        "C-r" = ":sh zellij run -c -f -n scooter -x 5%% -y 5%% --width 90%% --height 90%% -- scooter";
        "C-f" = ":sh zellij run -c -f -n yazi -x 5%% -y 5%% --width 90%% --height 90%% -- bash ~/.config/helix/yazi-picker.sh open %{buffer_name}";

        space = {
          q = ":quit";
          w = ":write";
          l = ":sh if [ '%{selection_line_start}' != '%{selection_line_end}' ]; then printf '%{buffer_name}:%{selection_line_start}-%{selection_line_end}'; else printf '%{buffer_name}:%{cursor_line}'; fi | wl-copy";
        };
      };

      keys.select = {
        X = "extend_line_above";
      };
    };

    languages = {
      language = [
        {
          name = "rust";
          language-servers = ["rust-analyzer"];
        }
        {
          name = "markdown";
          language-servers = ["marksman"];
        }
        {
          name = "nix";
          language-servers = ["nil"];
        }
        {
          name = "dart";
          language-servers = ["dart"];
        }
      ];

      language-server = {
        rust-analyzer = {
          command = "rust-analyzer";
          config = {
            checkOnSave.enable = true;
            procMacro.enable = true;
          };
        };

        nil = {
          command = "nil";
        };

        dart = {
          command = "dart";
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

  # FZF configuration
  programs.fzf = {
    enable = true;
    enableZshIntegration = true;
    defaultOptions = [
      "--style=full"
    ];
  };

  # Zsh shell configuration
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

    initExtra = ''
      WORDCHARS=''${WORDCHARS//[\/]}

      bindkey '^I'   complete-word
      bindkey '^[[Z' autosuggest-accept

      export PATH=~/.opencode/bin:$PATH
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

  # Ghostty terminal configuration (ported from macOS config)
  programs.ghostty = {
    enable = true;

    settings = {
      shell-integration-features = "no-cursor,no-title";
      gtk-titlebar = false;
      gtk-single-instance = true;
      adjust-cursor-thickness = 5;

      font-size = 13;

      window-title-font-family = "Berkeley Mono";

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

  # Helix yazi picker script
  home.file.".config/helix/yazi-picker.sh" = {
    executable = true;
    text = ''
      #!/usr/bin/env bash

      paths=$(yazi "$2" --chooser-file=/dev/stdout | while read -r; do printf "%q " "$REPLY"; done)

      if [[ -n "$paths" ]]; then
        zellij action toggle-floating-panes
        zellij action write 27 # send <Escape> key
        zellij action write-chars ":$1 $paths"
        zellij action write 13 # send <Enter> key
      else
        zellij action toggle-floating-panes
      fi
    '';
  };

  # Personal packages (moved from configuration.nix for better organization)
  home.packages = with pkgs; [
    # Terminal and multiplexer
    zellij
    
    # Personal applications
    ghostty
    helix
    yazi
    opencode
    gh
    zoxide
    
    # Development tools
    ripgrep
    fzf
    lazygit
    delta
    btop
    tokei
    just
    rust-analyzer
    nil
    marksman
    
    # Additional development tools
    bun
    ffmpeg
    curl
    samply
    yq-go
    lua-language-server
    rustup
    scooter
    cmake
    
    # Session management script
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

    # Helix-related shell script for yazi file picking
    (writeShellScriptBin "yz-fp" ''
      #!/usr/bin/env bash
      zellij action toggle-floating-panes
      zellij action write 27 # send escape key
      for selected_file in "$@"
      do
        zellij action write-chars ":open $selected_file"
        zellij action write 13 # send enter key
      done
      zellij action toggle-floating-panes
      zellij action close-pane
    '')
  ];
}
