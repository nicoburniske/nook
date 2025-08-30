{ config, pkgs, lib, ... }:

{
  programs.waybar = {
    enable = true;
    
    # Waybar settings configuration
    settings = {
      mainBar = {
        layer = "top";
        position = "top";
        height = 32;
        margin = "0 10 0 10";
        
        # Left: workspaces + window, Right: minimal system info, Center: empty (notch)
        modules-left = [ "hyprland/workspaces" "custom/separator" "hyprland/window" ];
        modules-center = [ ];
        modules-right = [ "cpu" "battery" "custom/clock" ];
        
        # Hyprland modules configuration
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
        
        # Simple separator like sketchybar's divider
        "custom/separator" = {
          format = "│";
          tooltip = false;
        };
        
        # Minimal system info modules - matching sketchybar style
        cpu = {
          format = "󰻠 {usage:02}%";  # Using nerd font equivalent of SF Symbol
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
          format-charging = "󰂄 {capacity}%";  # Charging icon
          format-plugged = "󰂄 {capacity}%";
          format-icons = ["󰂎" "󰁻" "󰁾" "󰂀" "󰁹"];  # Battery level icons
          tooltip = false;
        };
        
        # Custom clock module with lowercase formatting like sketchybar
        "custom/clock" = {
          exec = "date '+%a %b %d %H:%M' | tr '[:upper:]' '[:lower:]'";
          interval = 10;
          tooltip = false;
        };
      };
    };
    
    # Minimal style inspired by sketchybar - muted and clean
    style = with config.lib.stylix.colors; ''
      * {
        font-family: ${config.stylix.fonts.monospace.name};
        font-size: 13px;
        min-height: 0;
        border: none;
        border-radius: 0;
      }
      
      window#waybar {
        background: rgba(${base00-rgb-r}, ${base00-rgb-g}, ${base00-rgb-b}, 0.95);
        color: #${base04};
        padding: 0 10px;
      }
      
      #workspaces {
        background: transparent;
        margin: 0;
        padding: 0;
      }
      
      #workspaces button {
        background: rgba(${base01-rgb-r}, ${base01-rgb-g}, ${base01-rgb-b}, 0.6);
        color: #${base04};
        padding: 2px 8px;
        margin: 2px 2px;
        border-radius: 5px;
        border: 1px solid transparent;
        font-size: 11px;
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
        font-size: 14px;
      }
      
      #window {
        background: transparent;
        color: #${base04};
        padding: 0 4px;
        font-weight: normal;
      }
      
      #custom-clock {
        background: rgba(${base01-rgb-r}, ${base01-rgb-g}, ${base01-rgb-b}, 0.6);
        color: #${base04};
        padding: 0 8px;
        margin: 2px 4px;
        border-radius: 9px;
        font-weight: normal;
        font-size: 11px;
      }
      
      #cpu,
      #battery {
        background: transparent;
        border: 1px solid #${base03};
        color: #${base04};
        padding: 0 8px;
        margin: 2px 2px;
        border-radius: 9px;
        font-weight: normal;
        font-size: 11px;
      }
      
      #battery.warning {
        color: #${base08};
        border-color: #${base08};
      }
      
      .modules-left {
        margin-left: 0;
      }
      
      .modules-right {
        margin-right: 0;
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
