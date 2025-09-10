{...}: {
  programs.kitty = {
    enable = true;

    settings = {
      allow_remote_control = true;
      listen_on = "unix:/tmp/kitty";
      clear_all_shortcuts = true;

      tab_bar_style = "custom";
    };

    extraConfig = ''
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

      # Return to locked mode
      map --mode unlocked ctrl+space pop_keyboard_mode
      map --mode unlocked escape pop_keyboard_mode

      # Custom tab bar
      tab_bar_min_tabs 1
      tab_bar_edge bottom
    '';
  };

  xdg.configFile."kitty/tab_bar.py" = {
    text = ''

      from datetime import datetime
      from kitty.boss import get_boss
      from kitty.fast_data_types import Screen, add_timer, get_options
      from kitty.rgb import Color
      from kitty.utils import color_as_int
      from kitty.tab_bar import (
          DrawData,
          ExtraData,
          Formatter,
          TabBarData,
          as_rgb,
          draw_attributed_string,
          draw_title,
      )

      opts = get_options()
      mode_fg = as_rgb(color_as_int(opts.background))

      date_fgcolor = as_rgb(color_as_int(opts.tab_bar_background))
      date_bgcolor = as_rgb(color_as_int(opts.color9))
      # date_bgcolor = as_rgb(color_as_int(Color(251, 74, 52)))

      separator_fg = as_rgb(color_as_int(opts.color9))

      bat_text_color = as_rgb(color_as_int(opts.color15))
      SEPARATOR_SYMBOL, SOFT_SEPARATOR_SYMBOL = ("", "")
      RIGHT_MARGIN = 0

      def _draw_icon(screen: Screen, index: int) -> int:
          if index != 1:
              return 0
          fg, bg = screen.cursor.fg, screen.cursor.bg
          orig_bold = screen.cursor.bold
          # Get keyboard mode
          mode = get_boss().mappings.current_keyboard_mode_name
          if mode and mode == "unlocked":
              ICON = " UNLOCKED "
              screen.cursor.fg = mode_fg
              # Red for unlocked
              screen.cursor.bg = as_rgb(color_as_int(opts.color1))
          else:
              ICON = "  LOCKED  "
              screen.cursor.fg = mode_fg
              # Green for locked
              screen.cursor.bg = as_rgb(color_as_int(opts.color2))

          screen.cursor.bold = False
          screen.draw(ICON)
          screen.cursor.fg, screen.cursor.bg = fg, bg
          screen.cursor.bold = orig_bold
          screen.cursor.x = len(ICON)
          return screen.cursor.x


      def _draw_left_status(
          draw_data: DrawData,
          screen: Screen,
          tab: TabBarData,
          before: int,
          max_title_length: int,
          index: int,
          is_last: bool,
          extra_data: ExtraData,
      ) -> int:
          if screen.cursor.x >= screen.columns - right_status_length:
              return screen.cursor.x
          tab_bg = screen.cursor.bg
          tab_fg = screen.cursor.fg
          default_bg = as_rgb(int(draw_data.default_bg))
          if extra_data.next_tab:
              next_tab_bg = as_rgb(draw_data.tab_bg(extra_data.next_tab))
              needs_soft_separator = next_tab_bg == tab_bg
          else:
              next_tab_bg = default_bg
              needs_soft_separator = False
          # Use fixed ICON length since both modes pad to same width
          if screen.cursor.x <= len(" UNLOCKED "):
              screen.cursor.x = len(" UNLOCKED ")
          screen.draw(" ")
          screen.cursor.bg = tab_bg
          screen.cursor.bold = tab.is_active  # Bold only for active tab
          draw_title(draw_data, screen, tab, index)
          if not needs_soft_separator:
              screen.draw(" ")
              screen.cursor.fg = tab_bg
              screen.cursor.bg = next_tab_bg
              screen.draw(SEPARATOR_SYMBOL)
          else:
              prev_fg = screen.cursor.fg
              if tab_bg == tab_fg:
                  screen.cursor.fg = default_bg
              elif tab_bg != default_bg:
                  c1 = draw_data.inactive_bg.contrast(draw_data.default_bg)
                  c2 = draw_data.inactive_bg.contrast(draw_data.inactive_fg)
                  if c1 < c2:
                      screen.cursor.fg = default_bg
              screen.cursor.fg = prev_fg # separator_fg
              screen.draw(" " + SOFT_SEPARATOR_SYMBOL)
          end = screen.cursor.x
          return end


      def _draw_right_status(screen: Screen, is_last: bool, cells: list) -> int:
          if not is_last:
              return 0
          draw_attributed_string(Formatter.reset, screen)
          screen.cursor.x = screen.columns - right_status_length
          screen.cursor.fg = 0
          for bgColor, fgColor, status in cells:
              screen.cursor.fg = fgColor
              screen.cursor.bg = bgColor
              screen.draw(status)
          screen.cursor.bg = 0
          return screen.cursor.x


      def _redraw_tab_bar(_):
          tm = get_boss().active_tab_manager
          if tm is not None:
              tm.mark_tab_bar_dirty()


      right_status_length = -1

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
          global right_status_length
          date = datetime.now().strftime(" %d.%m.%Y")
          cells = [(date_bgcolor, date_fgcolor, date)]
          right_status_length = RIGHT_MARGIN
          for cell in cells:
              right_status_length += len(str(cell[2]))

          screen.cursor.italic = False
          _draw_icon(screen, index)
          _draw_left_status(
              draw_data,
              screen,
              tab,
              before,
              max_title_length,
              index,
              is_last,
              extra_data,
          )
          _draw_right_status(
              screen,
              is_last,
              cells,
          )
          return screen.cursor.x

    '';
  };
}
