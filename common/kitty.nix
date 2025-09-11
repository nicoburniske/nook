{config, ...}: {
  programs.kitty = {
    enable = true;
    shellIntegration = {
      enableZshIntegration = true;
      # auto-title is trash
      mode = "no-title";
    };

    settings = {
      allow_remote_control = true;
      listen_on = "unix:/tmp/kitty";
      clear_all_shortcuts = true;

      hide_window_decorations = "titlebar-only";
      window_padding_width = 5;

      tab_bar_style = "custom";
      tab_title_template = "{title}";
      active_tab_title_template = "{title}";
      tab_bar_min_tabs = 1;
      tab_bar_edge = "bottom";
      tab_powerline_style = "angled";
    };

    extraConfig = with config.lib.stylix.colors.withHashtag; ''
      inactive_tab_background ${base02}
      inactive_tab_foreground ${base05}
      active_tab_background ${base0C}
      active_tab_foreground ${base00}

      # === GLOBAL ===
      map shift+enter send_text all \n
      map ctrl+c copy_and_clear_or_interrupt
      map ctrl+v paste_from_clipboard
      map ctrl+equal change_font_size all +2.0
      map ctrl+minus change_font_size all -2.0

      # Toggle to unlocked mode
      map --new-mode unlocked ctrl+space

      # === UNLOCKED ===
      # Tab management
      map --mode unlocked ctrl+t new_tab_with_cwd
      map --mode unlocked ctrl+x close_tab
      map --mode unlocked ctrl+h previous_tab
      map --mode unlocked ctrl+l next_tab

      # Tab jumping with numbers
      map --mode unlocked ctrl+1 goto_tab 1
      map --mode unlocked ctrl+2 goto_tab 2
      map --mode unlocked ctrl+3 goto_tab 3
      map --mode unlocked ctrl+4 goto_tab 4
      map --mode unlocked ctrl+5 goto_tab 5
      map --mode unlocked ctrl+6 goto_tab 6
      map --mode unlocked ctrl+7 goto_tab 7
      map --mode unlocked ctrl+8 goto_tab 8
      map --mode unlocked ctrl+9 goto_tab 9

      # Tab reorganization
      map --mode unlocked ctrl+cmd+h move_tab_backward
      map --mode unlocked ctrl+cmd+l move_tab_forward
      map --mode unlocked ctrl+cmd+r set_tab_title

      # Return to locked mode
      map --mode unlocked ctrl+space pop_keyboard_mode
      map --mode unlocked escape pop_keyboard_mode

    '';
  };

  xdg.configFile."kitty/tab_bar.py" = {
    text = ''

      from kitty.boss import get_boss
      from kitty.fast_data_types import Screen, get_options
      from kitty.utils import color_as_int
      from kitty.tab_bar import (
          DrawData,
          ExtraData,
          TabBarData,
          as_rgb,
          draw_tab_with_powerline,
      )

      opts = get_options()
      mode_fg = as_rgb(color_as_int(opts.background))

      def _draw_mode(screen: Screen, index: int) -> int:
          if index != 1:
              return 0
          fg, bg = screen.cursor.fg, screen.cursor.bg
          orig_bold = screen.cursor.bold
          # Get keyboard mode
          mode = get_boss().mappings.current_keyboard_mode_name
          if mode and mode == "unlocked":
              MODE_TEXT = " UNLOCKED "
              screen.cursor.fg = mode_fg
              # Red for unlocked
              screen.cursor.bg = as_rgb(color_as_int(opts.color1))
          else:
              MODE_TEXT = "  LOCKED  "
              screen.cursor.fg = mode_fg
              # Green for locked
              screen.cursor.bg = as_rgb(color_as_int(opts.color2))

          screen.cursor.bold = False
          screen.draw(MODE_TEXT)
          screen.cursor.fg, screen.cursor.bg = fg, bg
          screen.cursor.bold = orig_bold
          screen.cursor.x = len(MODE_TEXT)
          return screen.cursor.x

      def draw_tab(
          draw_data: DrawData,
          screen: Screen,
          tab: TabBarData,
          before: int,
          max_title_length: int,
          index: int,
          is_last: bool,
          extra_data: ExtraData,
      ) -> int:
          screen.cursor.italic = False

          # Only draw mode for first tab and adjust positioning accordingly
          if index == 1:
              _draw_mode(screen, index)
              # Add spacing after the mode indicator
              screen.draw(" ")  # Add a space separator between mode and first tab
              # Now set the before position for the tab
              before = screen.cursor.x

          # Use the built-in powerline for tabs
          return draw_tab_with_powerline(
              draw_data,
              screen,
              tab,
              before,
              max_title_length,
              index,
              is_last,
              extra_data,
          )

    '';
  };
}
