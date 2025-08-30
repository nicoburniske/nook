{ config, pkgs, lib, ... }:

{
  programs.waybar = {
    enable = true;
    
    # Waybar settings configuration
    settings = {
      mainBar = {
        layer = "top";
        position = "top";
        height = 30;
        
        modules-left = [ "hyprland/workspaces" "hyprland/submap" ];
        modules-center = [ "hyprland/window" ];
        modules-right = [ "pulseaudio" "network" "cpu" "memory" "battery" "clock" "tray" ];
        
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
        
        "hyprland/submap" = {
          format = "✌️ {}";
          max-length = 8;
          tooltip = false;
        };
        
        # System monitoring modules
        cpu = {
          format = " {usage}%";
          tooltip = true;
          interval = 2;
        };
        
        memory = {
          format = " {}%";
          tooltip = true;
          tooltip-format = "Memory: {used:0.1f}G/{total:0.1f}G";
          interval = 2;
        };
        
        battery = {
          states = {
            warning = 30;
            critical = 15;
          };
          format = "{icon} {capacity}%";
          format-charging = " {capacity}%";
          format-plugged = " {capacity}%";
          format-icons = ["" "" "" "" ""];
        };
        
        # Network module
        network = {
          format-wifi = " {signalStrength}%";
          format-ethernet = " {ipaddr}";
          tooltip-format = "{ifname}: {ipaddr}/{cidr}";
          format-linked = " {ifname} (No IP)";
          format-disconnected = "Disconnected ⚠";
          format-alt = "{ifname}: {ipaddr}/{cidr}";
        };
        
        # Audio module
        pulseaudio = {
          scroll-step = 5;
          format = "{icon} {volume}%";
          format-muted = " {volume}%";
          format-icons = {
            default = ["" "" ""];
            headphone = "";
          };
          on-click = "pavucontrol";
        };
        
        # Clock module
        clock = {
          format = " {:%H:%M}";
          format-alt = " {:%Y-%m-%d}";
          tooltip-format = "<big>{:%Y %B}</big>\n<tt><small>{calendar}</small></tt>";
        };
        
        # System tray
        tray = {
          spacing = 10;
        };
      };
    };
    
    # Waybar style - using Stylix colors
    style = with config.lib.stylix.colors; ''
      * {
        font-family: ${config.stylix.fonts.monospace.name};
        font-size: 13px;
        min-height: 0;
      }
      
      window#waybar {
        background: rgba(${base00-rgb-r}, ${base00-rgb-g}, ${base00-rgb-b}, 0.9);
        color: #${base05};
        transition-property: background-color;
        transition-duration: .5s;
      }
      
      window#waybar.hidden {
        opacity: 0.2;
      }
      
      #workspaces button {
        padding: 0 5px;
        background: transparent;
        color: #${base04};
        border-bottom: 3px solid transparent;
      }
      
      #workspaces button:hover {
        background: rgba(${base02-rgb-r}, ${base02-rgb-g}, ${base02-rgb-b}, 0.5);
        color: #${base05};
      }
      
      #workspaces button.active {
        background: rgba(${base02-rgb-r}, ${base02-rgb-g}, ${base02-rgb-b}, 0.7);
        color: #${base05};
        border-bottom: 3px solid #${base0D};
      }
      
      #workspaces button.urgent {
        background-color: #${base08};
        color: #${base00};
      }
      
      #clock,
      #battery,
      #cpu,
      #memory,
      #disk,
      #temperature,
      #backlight,
      #network,
      #pulseaudio,
      #custom-media,
      #tray,
      #mode,
      #idle_inhibitor,
      #mpd,
      #submap,
      #window {
        padding: 0 10px;
        margin: 0 3px;
        color: #${base05};
      }
      
      #window,
      #workspaces {
        margin: 0 4px;
      }
      
      /* If workspaces is the leftmost module, omit left margin */
      .modules-left > widget:first-child > #workspaces {
        margin-left: 0;
      }
      
      /* If workspaces is the rightmost module, omit right margin */
      .modules-right > widget:last-child > #workspaces {
        margin-right: 0;
      }
      
      #clock {
        color: #${base0C};
      }
      
      #battery {
        color: #${base0B};
      }
      
      #battery.charging, #battery.plugged {
        color: #${base0B};
      }
      
      @keyframes blink {
        to {
          background-color: #${base05};
          color: #${base00};
        }
      }
      
      #battery.critical:not(.charging) {
        background-color: #${base08};
        color: #${base00};
        animation-name: blink;
        animation-duration: 0.5s;
        animation-timing-function: linear;
        animation-iteration-count: infinite;
        animation-direction: alternate;
      }
      
      #cpu {
        color: #${base0A};
      }
      
      #memory {
        color: #${base0E};
      }
      
      #network {
        color: #${base0D};
      }
      
      #network.disconnected {
        color: #${base08};
      }
      
      #pulseaudio {
        color: #${base0A};
      }
      
      #pulseaudio.muted {
        color: #${base03};
      }
      
      #tray {
        background-color: rgba(${base01-rgb-r}, ${base01-rgb-g}, ${base01-rgb-b}, 0.8);
        border-radius: 10px;
      }
      
      #tray > .passive {
        -gtk-icon-effect: dim;
      }
      
      #tray > .needs-attention {
        -gtk-icon-effect: highlight;
        background-color: #${base08};
      }
      
      #submap {
        background-color: #${base08};
        color: #${base00};
        border-radius: 10px;
      }
      
      tooltip {
        background: rgba(${base00-rgb-r}, ${base00-rgb-g}, ${base00-rgb-b}, 0.95);
        color: #${base05};
        border: 1px solid #${base02};
        border-radius: 10px;
      }
      
      tooltip label {
        color: #${base05};
      }
    '';
  };
}