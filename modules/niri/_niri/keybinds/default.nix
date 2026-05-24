{
  inputs,
  pkgs,
}: let
  scripts = import ./scripts.nix {
    inherit inputs pkgs;
  };
in ''
  Mod+Return repeat=false hotkey-overlay-title="Terminal" { spawn "kitty"; }
  Mod+Space repeat=false hotkey-overlay-title="Launcher" { spawn "fuzzel"; }
  Mod+B repeat=false hotkey-overlay-title="Browser" { spawn "${scripts.heliumProfile}/bin/helium-profile"; }
  Ctrl+Mod+Space repeat=false hotkey-overlay-title="Switch theme" { spawn "${scripts.themeSwitch}/bin/theme-switch"; }

  Ctrl+Alt+Super+L allow-inhibiting=false hotkey-overlay-title="Lock screen" { spawn "hyprlock"; }
  Ctrl+Alt+Super+Q hotkey-overlay-title="Exit niri" { quit skip-confirmation=true; }
  Mod+Q repeat=false { close-window; }

  Mod+F { maximize-column; }
  Mod+G { fullscreen-window; }
  Mod+V { toggle-window-floating; }
  Mod+Shift+V { switch-focus-between-floating-and-tiling; }
  Mod+S { toggle-column-tabbed-display; }

  Mod+H { focus-column-left; }
  Mod+J { focus-window-down; }
  Mod+K { focus-window-up; }
  Mod+L { focus-column-right; }
  Mod+Left { focus-column-left; }
  Mod+Down { focus-window-down; }
  Mod+Up { focus-window-up; }
  Mod+Right { focus-column-right; }

  Mod+Shift+H { move-column-left; }
  Mod+Shift+J { move-window-down; }
  Mod+Shift+K { move-window-up; }
  Mod+Shift+L { move-column-right; }
  Mod+Ctrl+H { move-column-left; }
  Mod+Ctrl+J { move-window-down; }
  Mod+Ctrl+K { move-window-up; }
  Mod+Ctrl+L { move-column-right; }

  Mod+Shift+Left { focus-monitor-left; }
  Mod+Shift+Down { focus-monitor-down; }
  Mod+Shift+Up { focus-monitor-up; }
  Mod+Shift+Right { focus-monitor-right; }
  Mod+Ctrl+Shift+Left { move-column-to-monitor-left; }
  Mod+Ctrl+Shift+Down { move-column-to-monitor-down; }
  Mod+Ctrl+Shift+Up { move-column-to-monitor-up; }
  Mod+Ctrl+Shift+Right { move-column-to-monitor-right; }

  Mod+BracketLeft { consume-or-expel-window-left; }
  Mod+BracketRight { consume-or-expel-window-right; }
  Mod+Comma { consume-window-into-column; }
  Mod+Period { expel-window-from-column; }

  Mod+Equal { switch-preset-column-width; }
  Mod+Minus { switch-preset-column-width-back; }
  Mod+R { switch-preset-column-width; }
  Mod+C { center-column; }
  Mod+Ctrl+C { center-visible-columns; }

  Mod+O repeat=false hotkey-overlay-title="Overview" { toggle-overview; }
  Mod+I repeat=false hotkey-overlay-title="Window switcher" { spawn "${scripts.windowSwitch}/bin/niri-window-switch"; }
  Mod+M repeat=false hotkey-overlay-title="Monitor options" { spawn "${scripts.monitorOptions}/bin/niri-monitor-options"; }
  Mod+U { focus-workspace-up; }
  Mod+D { focus-workspace-down; }
  Mod+Ctrl+U { move-column-to-workspace-up; }
  Mod+Ctrl+D { move-column-to-workspace-down; }
  Mod+Shift+U { move-workspace-up; }
  Mod+Shift+D { move-workspace-down; }

  Mod+1 repeat=false { focus-workspace 1; }
  Mod+2 repeat=false { focus-workspace 2; }
  Mod+3 repeat=false { focus-workspace 3; }
  Mod+4 repeat=false { focus-workspace 4; }
  Mod+5 repeat=false { focus-workspace 5; }
  Mod+6 repeat=false { focus-workspace 6; }
  Mod+7 repeat=false { focus-workspace 7; }
  Mod+8 repeat=false { focus-workspace 8; }
  Mod+9 repeat=false { focus-workspace 9; }
  Mod+0 repeat=false { focus-workspace 10; }

  Mod+Shift+1 repeat=false { move-window-to-workspace 1; }
  Mod+Shift+2 repeat=false { move-window-to-workspace 2; }
  Mod+Shift+3 repeat=false { move-window-to-workspace 3; }
  Mod+Shift+4 repeat=false { move-window-to-workspace 4; }
  Mod+Shift+5 repeat=false { move-window-to-workspace 5; }
  Mod+Shift+6 repeat=false { move-window-to-workspace 6; }
  Mod+Shift+7 repeat=false { move-window-to-workspace 7; }
  Mod+Shift+8 repeat=false { move-window-to-workspace 8; }
  Mod+Shift+9 repeat=false { move-window-to-workspace 9; }
  Mod+Shift+0 repeat=false { move-window-to-workspace 10; }

  Mod+Ctrl+1 { move-column-to-workspace 1; }
  Mod+Ctrl+2 { move-column-to-workspace 2; }
  Mod+Ctrl+3 { move-column-to-workspace 3; }
  Mod+Ctrl+4 { move-column-to-workspace 4; }
  Mod+Ctrl+5 { move-column-to-workspace 5; }
  Mod+Ctrl+6 { move-column-to-workspace 6; }
  Mod+Ctrl+7 { move-column-to-workspace 7; }
  Mod+Ctrl+8 { move-column-to-workspace 8; }
  Mod+Ctrl+9 { move-column-to-workspace 9; }
  Mod+Ctrl+0 { move-column-to-workspace 10; }

  Mod+WheelScrollDown cooldown-ms=140 { focus-column-right; }
  Mod+WheelScrollUp cooldown-ms=140 { focus-column-left; }
  Mod+Shift+WheelScrollDown cooldown-ms=140 { focus-workspace-down; }
  Mod+Shift+WheelScrollUp cooldown-ms=140 { focus-workspace-up; }
  Mod+Ctrl+Shift+WheelScrollDown cooldown-ms=140 { move-column-to-workspace-down; }
  Mod+Ctrl+Shift+WheelScrollUp cooldown-ms=140 { move-column-to-workspace-up; }

  Mod+P { screenshot-screen; }
  Mod+Shift+P { screenshot; }
  Print { screenshot; }
  Alt+Print { screenshot-window; }
  Ctrl+Print { screenshot-screen; }

  XF86MonBrightnessUp allow-when-locked=true { spawn "brightnessctl" "set" "5%+"; }
  XF86MonBrightnessDown allow-when-locked=true { spawn "brightnessctl" "set" "5%-"; }
  Shift+XF86MonBrightnessUp allow-when-locked=true { spawn "brightnessctl" "--device=kbd_backlight" "set" "5%+"; }
  Shift+XF86MonBrightnessDown allow-when-locked=true { spawn "brightnessctl" "--device=kbd_backlight" "set" "5%-"; }

  XF86AudioRaiseVolume allow-when-locked=true { spawn "wpctl" "set-volume" "-l" "1.0" "@DEFAULT_SINK@" "5%+"; }
  XF86AudioLowerVolume allow-when-locked=true { spawn "wpctl" "set-volume" "-l" "1.0" "@DEFAULT_SINK@" "5%-"; }
  XF86AudioMute allow-when-locked=true { spawn "wpctl" "set-mute" "@DEFAULT_SINK@" "toggle"; }
  XF86AudioMicMute allow-when-locked=true { spawn "wpctl" "set-mute" "@DEFAULT_AUDIO_SOURCE@" "toggle"; }

  Mod+Escape allow-inhibiting=false { toggle-keyboard-shortcuts-inhibit; }
''
