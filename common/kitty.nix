{...}: {
  programs.kitty = {
    enable = true;

    settings = {
      allow_remote_control = true;
      listen_on = "unix:/tmp/kitty";
      clear_all_shortcuts = true;

      tab_title_template = "{fmt.fg.red}{keyboard_mode}{fmt.fg.tab}{title}";
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
}
