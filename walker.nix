{ config, ... }:

{
  services.walker = {
    enable = true;
    
    settings = {
      force_keyboard_focus = true;
      
      # Window sizing and constraints like omarchy
      ui.window.box = {
        width = 664;
        min_width = 664;
        max_width = 664;
        height = 396;
        min_height = 396;
        max_height = 396;
      };
      
      # List constraints are critical - without these, the window shrinks when empty
      ui.window.box.scroll.list = {
        height = 300;
        min_height = 300;
        max_height = 300;
      };
      
      # Smaller icon size
      ui.window.box.scroll.list.item.icon = {
        pixel_size = 24;
      };
      
      providers = {
        default = [ "desktopapplications" ];
        prefixes = [
          { prefix = "?"; provider = "websearch"; }
        ];
      };
    };

    theme = {
      name = "stylix";
      style = with config.lib.stylix.colors; ''
        /* Define color variables */
        @define-color background #${base00};
        @define-color foreground #${base05};
        @define-color text #${base04};
        @define-color selected-text #${base05};
        @define-color base #${base01};
        @define-color border #${base03};

        /* Reset all elements */
        #window,
        #box,
        #search,
        #password,
        #input,
        #prompt,
        #clear,
        #typeahead,
        #list,
        child,
        scrollbar,
        slider,
        #item,
        #text,
        #label,
        #sub,
        #activationlabel {
          all: unset;
        }

        * {
          font-family: ${config.stylix.fonts.monospace.name};
          font-size: ${toString config.stylix.fonts.sizes.desktop}px;
        }

        /* Window */
        #window {
          background: transparent;
          color: @text;
        }

        /* Main box container */
        #box {
          background: alpha(@base, 0.95);
          padding: 20px;
          border: 2px solid @border;
          border-radius: 8px;
        }

        /* Search container */
        #search {
          background: @background;
          padding: 10px;
          margin-bottom: 8px;
          border-radius: 4px;
          border: 1px solid @border;
        }

        /* Hide prompt icon */
        #prompt {
          opacity: 0;
          min-width: 0;
          margin: 0;
        }

        /* Hide clear button */
        #clear {
          opacity: 0;
          min-width: 0;
        }

        /* Input field */
        #input {
          background: none;
          color: @text;
          padding: 0;
        }

        #input placeholder {
          opacity: 0.5;
          color: @text;
        }

        /* Hide typeahead */
        #typeahead {
          opacity: 0;
        }

        /* List */
        #list {
          background: transparent;
          padding-top: 10px;
        }

        /* List items */
        child {
          padding: 0px 12px;
          background: transparent;
          border-radius: 4px;
          margin: 1px 0;
        }

        child:selected,
        child:hover {
          background: alpha(@selected-text, 0.1);
        }

        /* Item layout */
        #item {
          padding: 0;
        }

        #item.active {
          font-style: italic;
        }

        /* Icon */
        #icon {
          margin-right: 12px;
          -gtk-icon-transform: scale(0.8);
        }

        /* Text */
        #text {
          color: @text;
          padding: 8px 0;
        }

        #label {
          font-weight: normal;
        }

        /* Selected state */
        child:selected #text,
        child:selected #label,
        child:hover #text,
        child:hover #label {
          color: @selected-text;
        }

        /* Hide sub text */
        #sub {
          opacity: 0;
          font-size: 0;
          min-height: 0;
        }

        /* Hide activation label */
        #activationlabel {
          opacity: 0;
          min-width: 0;
        }

        /* Scrollbar styling */
        scrollbar {
          opacity: 0;
        }

        /* Hide spinner */
        #spinner {
          opacity: 0;
        }

        /* Hide AI elements */
        #aiScroll,
        #aiList,
        .aiItem {
          opacity: 0;
          min-height: 0;
        }

        /* Bar entry (switcher) */
        #bar {
          opacity: 0;
          min-height: 0;
        }

        .barentry {
          opacity: 0;
        }
      '';
    };
  };
}