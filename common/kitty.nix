{...}: {
  programs.kitty = {
    enable = true;
    
    settings = {
      # Enable remote control for overlay functionality
      allow_remote_control = true;
      listen_on = "unix:/tmp/kitty";
      
      # Optional: Show keyboard mode in tab title for visual feedback
      tab_title_template = "{fmt.fg.red}{keyboard_mode}{fmt.fg.tab} {title}";
    };
    
    keybindings = {
      # Port Ghostty keybindings (always active in all modes)
      "shift+enter" = "send_text all \\n";
      "ctrl+c" = "copy_and_clear_or_interrupt";
      "ctrl+v" = "paste_from_clipboard";
    };
    
    # Use extraConfig for the modal mappings since home-manager doesn't handle them well
    extraConfig = ''
      # Create a new "normal" mode for kitty management (like zellij unlock)
      # Ctrl+Space toggles between locked and normal mode
      map --new-mode normal ctrl+space
      
      # === Normal mode keybindings (active when unlocked) ===
      
      # Tab management
      map --mode normal ctrl+h previous_tab
      map --mode normal ctrl+l next_tab
      map --mode normal ctrl+t new_tab
      map --mode normal ctrl+w close_tab
      map --mode normal ctrl+shift+t new_tab_with_cwd
      
      # Window management
      map --mode normal ctrl+n new_window
      map --mode normal ctrl+shift+n new_window_with_cwd
      map --mode normal ctrl+shift+w close_window
      map --mode normal ctrl+j neighboring_window down
      map --mode normal ctrl+k neighboring_window up
      
      # Tab jumping with numbers
      map --mode normal ctrl+1 goto_tab 1
      map --mode normal ctrl+2 goto_tab 2
      map --mode normal ctrl+3 goto_tab 3
      map --mode normal ctrl+4 goto_tab 4
      map --mode normal ctrl+5 goto_tab 5
      map --mode normal ctrl+6 goto_tab 6
      map --mode normal ctrl+7 goto_tab 7
      map --mode normal ctrl+8 goto_tab 8
      map --mode normal ctrl+9 goto_tab 9
      
      # Layout management
      map --mode normal ctrl+shift+l next_layout
      
      # Exit normal mode back to locked (Ctrl+Space or Escape)
      map --mode normal ctrl+space pop_keyboard_mode
      map --mode normal escape pop_keyboard_mode
    '';
  };
}