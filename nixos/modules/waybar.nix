{config, ...}: {
  programs.waybar = {
    enable = true;

    settings = {
      mainBar = {
        layer = "top";
        position = "top";
        height = 40;

        modules-left = ["hyprland/workspaces" "custom/separator" "hyprland/window"];
        modules-center = [];
        modules-right = ["tray" "bluetooth" "network" "pulseaudio" "cpu" "battery" "custom/clock"];

        "hyprland/workspaces" = {
          disable-scroll = false;
          all-outputs = true;
          on-scroll-up = "hyprctl dispatch workspace e+1";
          on-scroll-down = "hyprctl dispatch workspace e-1";
          format = "{name}";
          format-icons = {
            urgent = "";
            active = "";
            default = "";
          };
        };

        "hyprland/window" = {
          format = "{}";
          separate-outputs = true;
          max-length = 50;
        };

        "custom/separator" = {
          format = "│";
          tooltip = false;
        };

        cpu = {
          format = " {usage:02}%";
          tooltip = false;
          interval = 5;
        };

        battery = {
          states = {
            good = 90;
            medium = 60;
            low = 30;
            warning = 10;
          };
          format = "{icon} {capacity}%";
          format-charging = "󰂄 {capacity}%";
          format-plugged = "󰂄 {capacity}%";
          format-icons = ["󰂎" "󰁻" "󰁾" "󰂀" "󰁹"];
          tooltip = false;
        };

        "custom/clock" = {
          exec = "date '+%a %b %d %H:%M' | tr '[:upper:]' '[:lower:]'";
          interval = 10;
          tooltip = false;
        };

        pulseaudio = {
          format = "{icon} {volume}%";
          format-muted = "󰝟 muted";
          format-icons = {
            default = ["" "" ""];
          };
          on-click = "wpctl set-mute @DEFAULT_SINK@ toggle";
          on-click-right = "pavucontrol";
          scroll-step = 5;
          tooltip = true;
          tooltip-format = "{desc} • {volume}%";
        };

        network = {
          format-wifi = " {signalStrength}%";
          format-ethernet = "󰈀";
          format-disconnected = "󰖪";
          tooltip-format-wifi = "{essid} ({frequency} GHz)\n⇣{bandwidthDownBytes}  ⇡{bandwidthUpBytes}";
          tooltip-format-ethernet = "{ifname}\n⇣{bandwidthDownBytes}  ⇡{bandwidthUpBytes}";
          tooltip-format-disconnected = "Disconnected";
          interval = 3;
          on-click = "nm-connection-editor";
        };

        bluetooth = {
          format = "";
          format-disabled = "󰂲";
          format-connected = " {num_connections}";
          tooltip-format = "{controller_alias}\t{controller_address}";
          tooltip-format-connected = "{controller_alias}\t{controller_address}\n\n{device_enumerate}";
          tooltip-format-enumerate-connected = "{device_alias}\t{device_address}";
          on-click = "blueman-manager";
        };

        tray = {
          icon-size = 14;
          spacing = 8;
        };
      };
    };

    style = with config.lib.stylix.colors; let
      fontSize = toString config.stylix.fonts.sizes.desktop;
    in ''
      * {
        font-family: ${config.stylix.fonts.monospace.name}, ${config.stylix.fonts.emoji.name};
        font-size: ${fontSize}px;
        min-height: 0;
        border: none;
        border-radius: 0;
      }

      window#waybar {
        background: rgba(${base00-rgb-r}, ${base00-rgb-g}, ${base00-rgb-b}, 0.95);
        color: #${base04};
      }

      #workspaces {
        background: transparent;
        margin: 0;
        padding: 0;
      }

      #workspaces button {
        background: rgba(${base01-rgb-r}, ${base01-rgb-g}, ${base01-rgb-b}, 0.6);
        color: #${base04};
        padding: 0 8px;
        margin: 5px 2px;
        border-radius: 5px;
        border: 1px solid transparent;
        font-size: ${fontSize}px;
        min-width: 20px;
      }

      #workspaces button:hover {
        background: rgba(${base02-rgb-r}, ${base02-rgb-g}, ${base02-rgb-b}, 0.7);
        color: #${base05};
      }

      #workspaces button.active {
        background: rgba(${base02-rgb-r}, ${base02-rgb-g}, ${base02-rgb-b}, 0.8);
        color: #${base05};
        border: 1px solid rgba(${base0D-rgb-r}, ${base0D-rgb-g}, ${base0D-rgb-b}, 0.5);
      }

      #workspaces button.urgent {
        background: rgba(${base08-rgb-r}, ${base08-rgb-g}, ${base08-rgb-b}, 0.8);
        color: #${base00};
      }

      #custom-separator {
        color: #${base03};
        background: transparent;
        padding: 0 8px;
        font-size: ${fontSize}px;
      }

      #window {
        background: transparent;
        color: #${base05};
        padding: 0 4px;
        font-weight: normal;
      }

      #custom-clock {
        background: rgba(${base01-rgb-r}, ${base01-rgb-g}, ${base01-rgb-b}, 0.6);
        color: #${base05};
        padding: 0 8px;
        margin: 5px 2px;
        border-radius: 9px;
        font-weight: normal;
        font-size: ${fontSize}px;
      }

      #cpu,
      #battery,
      #pulseaudio,
      #network,
      #bluetooth {
        background: transparent;
        border: 1px solid #${base03};
        color: #${base05};
        padding: 0 8px;
        margin: 5px 2px;
        border-radius: 9px;
        font-weight: normal;
        font-size: ${fontSize}px;
      }

      #pulseaudio.muted {
        color: #${base03};
      }

      #network.disconnected {
        color: #${base08};
        border-color: #${base08};
      }

      #bluetooth.disabled {
        color: #${base03};
      }

      #tray {
        background: transparent;
        padding: 0 4px;
        margin: 5px 2px;
      }

      #tray > .passive {
        -gtk-icon-effect: dim;
      }

      #tray > .needs-attention {
        -gtk-icon-effect: highlight;
        background-color: #${base08};
      }

      #battery.warning {
        color: #${base08};
        border-color: #${base08};
      }

      .modules-left {
        margin-left: 10px;
      }

      .modules-right {
        margin-right: 10px;
      }

      tooltip {
        background: rgba(${base00-rgb-r}, ${base00-rgb-g}, ${base00-rgb-b}, 0.9);
        color: #${base05};
        border: 1px solid rgba(${base02-rgb-r}, ${base02-rgb-g}, ${base02-rgb-b}, 0.5);
        border-radius: 5px;
      }
    '';
  };
}
