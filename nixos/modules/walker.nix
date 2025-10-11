{config, ...}: {
  programs.walker = {
    enable = true;
    runAsService = true;

    config = {
      force_keyboard_focus = true;
      hotreload_theme = true;

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
        pixel_size = 40;
      };

      builtins.applications = {
        prioritize_new = false;
        context_aware = false;
        show_sub_when_single = false;
        history = false;
        icon = "";
        hidden = true;

        actions = {
          enabled = false;
          hide_category = true;
        };
      };
    };

    theme = {
      name = "stylix";
      style = with config.lib.stylix.colors; ''
        @define-color window_bg_color #${base00};
        @define-color accent_bg_color #${base02};
        @define-color theme_fg_color #${base05};
        @define-color error_bg_color #${base00};
        @define-color error_fg_color #${base08};
        @define-color border_color #${base0D};

        * {
          font-family: ${config.stylix.fonts.monospace.name};
          font-size: ${toString config.stylix.fonts.sizes.desktop}px;
        }

        * {
          all: unset;
        }

        .normal-icons {
          -gtk-icon-size: 16px;
        }

        .large-icons {
          -gtk-icon-size: 24px;
        }

        scrollbar {
          opacity: 0;
        }

        .box-wrapper {
          background: @window_bg_color;
          padding: 10px;
          border: 1px solid @border_color;
        }

        .preview-box,
        .elephant-hint,
        .placeholder {
          color: @theme_fg_color;
        }

        .box {
        }

        .search-container {
        }

        .input placeholder {
          opacity: 0.5;
        }

        .input {
          caret-color: @theme_fg_color;
          background: lighter(@window_bg_color);
          padding: 10px;
          color: @theme_fg_color;
        }

        .input:focus,
        .input:active {
        }

        .content-container {
        }

        .placeholder {
        }

        .scroll {
        }

        .list {
          color: @theme_fg_color;
        }

        child {
        }

        .item-box {
          padding: 4px;
        }

        .item-quick-activation {
          margin-left: 10px;
          background: alpha(@accent_bg_color, 0.25);
          padding: 10px;
        }

        child:hover .item-box,
        child:selected .item-box {
          background: alpha(@accent_bg_color, 0.25);
        }

        .item-text-box {
        }

        .item-text {
        }

        .item-subtext {
          font-size: 12px;
          opacity: 0.5;
        }

        .item-image,
        .item-image-text {
          margin-right: 10px;
        }

        .item-image-text {
          font-size: 28px;
        }

        .preview {
          border: 1px solid @accent_bg_color;
          padding: 10px;
          color: @theme_fg_color;
        }

        .calc .item-text {
          font-size: 24px;
        }

        .calc .item-subtext {
        }

        .symbols .item-image {
          font-size: 24px;
        }

        .todo.done .item-text-box {
          opacity: 0.25;
        }

        .todo.urgent {
          font-size: 24px;
        }

        .todo.active {
          font-weight: bold;
        }

        .bluetooth.disconnected {
          opacity: 0.5;
        }

        .preview .large-icons {
          -gtk-icon-size: 64px;
        }

        .keybinds-wrapper {
          border-top: 1px solid lighter(@window_bg_color);
          font-size: 12px;
          opacity: 0.5;
          color: @theme_fg_color;
        }

        .keybinds {
        }

        .keybind {
        }

        .keybind-bind {
          /* color: lighter(@window_bg_color); */
          font-weight: bold;
        }

        .keybind-label {
        }

        .error {
          padding: 10px;
          background: @error_bg_color;
          color: @error_fg_color;
        }
      '';
    };
  };
}
