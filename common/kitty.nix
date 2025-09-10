{config, ...}: {
  programs.kitty = {
    enable = true;

    settings = {
      allow_remote_control = true;
      listen_on = "unix:/tmp/kitty";
      clear_all_shortcuts = true;

      tab_bar_style = "custom";
      tab_bar_custom_draw_function = "${config.home.homeDirectory}/.config/kitty/tab_bar.py:draw_tab";
    };

    extraConfig = ''
      # === GLOBAL KEYBINDINGS ===
      map shift+enter send_text all \n
      map ctrl+c copy_and_clear_or_interrupt
      map ctrl+v paste_from_clipboard
      map ctrl+equal change_font_size all +2.0
      map ctrl+minus change_font_size all -2.0

      # Toggle to unlocked mode
      map --new-mode unlocked ctrl+space

      # === UNLOCKED MODE ===
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

      # Return to locked mode (Ctrl+Space or Escape)
      map --mode unlocked ctrl+space pop_keyboard_mode
      map --mode unlocked escape pop_keyboard_mode
    '';
  };

  xdg.configFile."kitty/tab_bar.py" = {
    text = ''
      # pyright: reportMissingImports=false
      from kitty.boss import get_boss
      from kitty.fast_data_types import Screen, get_options
      from kitty.tab_bar import DrawData, ExtraData, TabBarData, as_rgb, color_as_int

      opts = get_options()

      def get_tab_info(tab: TabBarData):
          tm = get_boss().active_tab_manager
          for t in tm.tabs:
              if t.id == tab.tab_id:
                  active_window = t.active_window
                  if active_window:
                      cwd = active_window.cwd_of_child or "?"
                      program = "?"
                      if active_window.child and active_window.child.foreground_processes:
                          cmdline = active_window.child.foreground_processes[0].get("cmdline")
                          if cmdline:
                              program = cmdline[0].rsplit("/", 1)[-1]
                      cwd_last = cwd.rsplit("/", 1)[-1] if cwd != "?" else "?"
                      return cwd_last, program
          return "?", "?"

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
          cwd_last, program = get_tab_info(tab)

          # Colors from stylix via get_options
          active_fg = as_rgb(color_as_int(opts.color15)) if hasattr(opts, 'color15') else 0xffffff
          inactive_fg = as_rgb(color_as_int(opts.color8)) if hasattr(opts, 'color8') else 0x888888
          active_bg = as_rgb(color_as_int(opts.color0)) if hasattr(opts, 'color0') else 0x000000
          inactive_bg = as_rgb(color_as_int(opts.color8)) if hasattr(opts, 'color8') else 0x333333

          fg = active_fg if tab.is_active else inactive_fg
          bg = active_bg if tab.is_active else inactive_bg

          screen.cursor.fg = fg
          screen.cursor.bg = bg

          text = f"[{index}] {cwd_last}: {program}"
          if len(text) > max_title_length:
              text = text[:max_title_length - 3] + "..."

          screen.draw(" " + text + " ")

          if not is_last:
              screen.draw(" ")

          return screen.cursor.x
    '';
  };
}
