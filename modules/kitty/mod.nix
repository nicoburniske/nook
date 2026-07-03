{...}: let
  tabTitle = "{'  ' if layout_name == 'stack' and num_windows > 1 else ''}{title}";
  renderTheme = import ./_theme.nix;
  kitty = {pkgs, ...}: {
    environment.systemPackages = [pkgs.kitty];

    sumi.configFile = {
      "kitty/kitty.conf".value = ''
        auto_reload_config -1
        shell_integration no-rc no-title

        active_tab_title_template ${tabTitle}
        allow_remote_control yes
        clear_all_shortcuts yes
        confirm_os_window_close 0
        cursor_trail 3
        cursor_trail_decay 0.1 0.4
        enable_audio_bell no
        enabled_layouts stack,tall
        hide_window_decorations titlebar-only
        listen_on unix:/tmp/kitty
        scrollback_lines 1000000000
        tab_bar_edge bottom
        tab_bar_margin_height 2.0 2.0
        tab_bar_min_tabs 1
        tab_bar_style custom
        tab_powerline_style angled
        tab_title_template ${tabTitle}
        window_padding_width 5

        include ~/.config/kitty/themes/sumi.conf

        # === GLOBAL ===

        map shift+enter send_text all \n
        map ctrl+c copy_and_clear_or_interrupt
        map ctrl+v paste_from_clipboard
        map ctrl+equal change_font_size all +2.0
        map ctrl+minus change_font_size all -2.0
        map ctrl+shift+, load_config_file

        map --new-mode unlocked ctrl+space

        # === UNLOCKED ===

        map --mode unlocked ctrl+t new_tab_with_cwd
        map --mode unlocked ctrl+p previous_tab
        map --mode unlocked ctrl+n next_tab
        map --mode unlocked shift+n move_tab_forward
        map --mode unlocked shift+p move_tab_backward

        map --mode unlocked ctrl+w new_window_with_cwd
        map --mode unlocked ctrl+h neighboring_window left
        map --mode unlocked ctrl+j neighboring_window down
        map --mode unlocked ctrl+k neighboring_window up
        map --mode unlocked ctrl+l neighboring_window right

        map --mode unlocked shift+h move_window left
        map --mode unlocked shift+j move_window down
        map --mode unlocked shift+k move_window up
        map --mode unlocked shift+l move_window right

        map --mode unlocked ctrl+x close_window
        map --mode unlocked ctrl+shift+x close_tab

        map --mode unlocked cmd+h resize_window narrower
        map --mode unlocked cmd+l resize_window wider
        map --mode unlocked cmd+k resize_window taller
        map --mode unlocked cmd+j resize_window shorter

        map --mode unlocked ctrl+f next_layout

        # search with scrollback
        map --mode unlocked ctrl+/ combine | launch --stdin-source=@last_cmd_output --type=overlay hx | pop_keyboard_mode

        map --mode unlocked ctrl+1 goto_tab 1
        map --mode unlocked ctrl+2 goto_tab 2
        map --mode unlocked ctrl+3 goto_tab 3
        map --mode unlocked ctrl+4 goto_tab 4
        map --mode unlocked ctrl+5 goto_tab 5
        map --mode unlocked ctrl+6 goto_tab 6
        map --mode unlocked ctrl+7 goto_tab 7
        map --mode unlocked ctrl+8 goto_tab 8
        map --mode unlocked ctrl+9 goto_tab 9

        map --mode unlocked ctrl+space pop_keyboard_mode
        map --mode unlocked escape pop_keyboard_mode
      '';

      "kitty/themes/sumi.conf" = {
        watch = "theme";
        value = ctx: renderTheme ctx.value;
      };
      "kitty/tab_bar.py".value = ./tab_bar.py;

      "kitty/quick-access-terminal.conf".value = ''
        edge center-sized
        lines 20
        columns 50
        kitty_override tab_bar_style=hidden
      '';
    };

    sumi.hook.kitty = {
      watch = "theme";
      command =
        if pkgs.stdenv.isDarwin
        then "/usr/bin/pkill -USR1 .kitty-wrapped"
        else "${pkgs.procps}/bin/pkill -USR1 .kitty-wrapped";
    };
  };

  niriRulesModule = {
    compositor.niri.rules = [
      {
        window-rule = {
          match."app-id" = "^kitty$";
          scroll-factor = 1.5;
          background-effect = [{blur = true;}];
        };
      }
    ];
  };
in {
  flake.mod.nixos.kitty = {
    imports = [
      kitty
      niriRulesModule
    ];
  };
  flake.mod.darwin.kitty = kitty;
}
