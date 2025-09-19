{config, ...}: {
  stylix.targets.waybar.addCss = false;

  programs.waybar = {
    enable = true;

    settings = {
      mainBar = {
        layer = "top";
        position = "top";
        height = 40;

        modules-left = ["hyprland/workspaces"];
        modules-center = [];
        modules-right = ["tray" "group/indicators" "cpu" "battery" "custom/clock"];

        "group/indicators" = {
          orientation = "horizontal";
          modules = ["bluetooth" "network" "pulseaudio"];
        };

        "hyprland/workspaces" = {
          disable-scroll = false;
          all-outputs = true;
          on-scroll-up = "hyprctl dispatch workspace e+1";
          on-scroll-down = "hyprctl dispatch workspace e-1";
          format = "{name}";
          persistent-workspaces = {
            "1" = [];
            "2" = [];
            "3" = [];
            "4" = [];
          };
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
          format = "{icon} {capacity}%";
          format-icons = {
            default = ["󰁺" "󰁻" "󰁼" "󰁽" "󰁾" "󰁿" "󰂀" "󰂁" "󰂂" "󰁹"];
          };
          format-charging = "󰂄 {capacity}%";
          format-plugged = "󰂄 {capacity}%";
          format-full = "󰂅";
          tooltip-format-discharging = "{power:>1.0f}W↓ {capacity}%";
          tooltip-format-charging = "{power:>1.0f}W↑ {capacity}%";

          interval = 5;
          states = {
            warning = 20;
          };
        };

        "custom/clock" = {
          exec = "date '+%a %b %d %H:%M' | tr '[:upper:]' '[:lower:]'";
          interval = 10;
          tooltip = false;
        };

        pulseaudio = {
          format = "{icon}";
          on-click = "kitty --class wiremix wiremix";
          tooltip-format = "Playing at {volume}%";
          scroll-step = 5;
          format-muted = "󰝟";
          format-icons = {
            "default" = ["" "" ""];
          };
        };

        network = {
          on-click = "kitty --class nmtui nmtui";
          format-icons = ["󰤯" "󰤟" "󰤢" "󰤥" "󰤨"];
          format = "{icon}";
          format-wifi = "{icon}";
          format-ethernet = "󰀂";
          format-disconnected = "󰖪";
          tooltip-format-wifi = "{essid} ({frequency} GHz)\n⇣{bandwidthDownBytes}  ⇡{bandwidthUpBytes}";
          tooltip-format-ethernet = "⇣{bandwidthDownBytes}  ⇡{bandwidthUpBytes}";
          tooltip-format-disconnected = "disconnected";
          interval = 3;
          spacing = 1;
        };

        bluetooth = {
          format = "";
          format-disabled = "󰂲";
          format-connected = "";
          tooltip-format = "devices connected= {num_connections}";
          on-click = "kitty --class bluetui bluetui";
        };

        tray = {
          icon-size = 14;
          spacing = 8;
        };
      };
    };

    style = with config.lib.stylix.colors; let
      fontSize = toString config.stylix.fonts.sizes.desktop;
      borderRadius = "5px";
      elementMargin = "8px 2px";
      elementPadding = "2px 8px";
      elementBackground = "#${base01}";
      elementBorder = "1px solid #${base03}";
    in ''
      * {
        font-family: ${config.stylix.fonts.monospace.name}, ${config.stylix.fonts.emoji.name};
        font-size: ${fontSize}px;
        min-height: 0;
        border: none;
        border-radius: 0;
      }

      window#waybar {
        background: transparent;
        color: #${base04};
      }

      #workspaces {
        background: ${elementBackground};
        border: ${elementBorder};
        border-radius: ${borderRadius};
        margin: ${elementMargin};
        padding: 0px 4px;
      }

      #workspaces button {
        background: transparent;
        color: #${base05};
        padding: 4px 6px 4px 6px;
        margin: 0 1px;
        border-top: 2px solid transparent;
        border-bottom: 2px solid transparent;

        font-size: ${fontSize}px;
        min-width: 20px;
        transition: all 0.3s ease;
      }

      #workspaces button:hover {
        color: #${base05};
      }

      #workspaces button.active {
        border-bottom: 2px solid #${base05};
      }

      #workspaces button.urgent {
        color: #${base08};
      }

      #window {
        background: transparent;
        color: #${base05};
        padding: 0 4px;
        font-weight: normal;
      }

      #custom-clock {
        background: ${elementBackground};
        border: ${elementBorder};
        color: #${base05};
        padding: ${elementPadding};
        margin: ${elementMargin};
        border-radius: ${borderRadius};
        font-weight: normal;
        font-size: ${fontSize}px;
      }

      #cpu,
      #battery {
        background: ${elementBackground};
        border: ${elementBorder};
        color: #${base05};
        padding: ${elementPadding};
        margin: ${elementMargin};
        border-radius: ${borderRadius};
        font-weight: normal;
        font-size: ${fontSize}px;
      }

      #indicators {
        background: ${elementBackground};
        border: ${elementBorder};
        border-radius: ${borderRadius};
        margin: ${elementMargin};
        padding: 2px 4px;
      }

      #pulseaudio,
      #network,
      #bluetooth {
        color: #${base05};
        padding: 0 6px;
        margin: 0;
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
        margin: ${elementMargin};
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
        border-radius: ${borderRadius};
      }
    '';
  };
}
