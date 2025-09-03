{
  config,
  lib,
  pkgs,
  ...
}:
# just inline stylix theme
# to support zellij config reloading at runtime
# struggles to reload with sym-links
# theme copy-paste from https://github.com/nix-community/stylix/blob/master/modules/zellij/hm.nix
let
  fileName = "home_manager_config.kdl";
in {
  xdg.configFile."zellij/${fileName}" = {
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
    text = ''
      layout {
          pane
          pane size=1 borderless=true {
              plugin location="compact-bar"
          }
      }
    '';
  };
  home.packages = with pkgs; [
    zellij

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

    (writeShellScriptBin "zj-rm" ''
      #!/usr/bin/env bash
      SESSION_NAME="$1"

      if [ -z "$SESSION_NAME" ]; then
        echo "Usage: zellij-rm <session_name>"
        exit 1
      fi

      zellij kill-session "$SESSION_NAME"
      zellij delete-session "$SESSION_NAME"

      rm -rf "$HOME/.cache/zellij/*/session_info/$SESSION_NAME/"
      rm -f "/run/user/$(id -u)/zellij/*/$SESSION_NAME"

      echo "Session $SESSION_NAME removed completely"
    '')
  ];

  # Always ensure config.kdl is a real file (not symlink) for runtime reloading
  home.activation.zellijConfig = lib.hm.dag.entryAfter ["writeBoundary"] ''
    if [ -f ${config.xdg.configHome}/zellij/${fileName} ]; then
      rm -f ${config.xdg.configHome}/zellij/config.kdl
      cp ${config.xdg.configHome}/zellij/${fileName} ${config.xdg.configHome}/zellij/config.kdl
      chmod u+w ${config.xdg.configHome}/zellij/config.kdl
    fi
  '';
}
