{
  inputs,
  pkgs,
}: let
  cmd = import ./cmd.nix {
    inherit inputs pkgs;
  };
  focusVertical = pkgs.writeNuScriptBin "focus-vertical" {
    runtimeInputs = [pkgs.niri];
    source = ./focus-vertical.nu;
  };
in ''
  Mod+Return repeat=false hotkey-overlay-title="Terminal" { spawn "kitty"; }
  Mod+Space repeat=false hotkey-overlay-title="Launcher" { spawn "fuzzel"; }
  Mod+Ctrl+Space repeat=false hotkey-overlay-title="Scripts" { spawn "${cmd}/bin/niri-cmd"; }

  Ctrl+Alt+Super+L allow-inhibiting=false hotkey-overlay-title="Lock screen" { spawn "hyprlock"; }
  Ctrl+Alt+Super+Q hotkey-overlay-title="Exit niri" { quit skip-confirmation=true; }
  Mod+Q repeat=false { close-window; }

  Mod+F { maximize-column; }
  Mod+G { fullscreen-window; }
  Mod+V { toggle-window-floating; }
  Mod+S { toggle-column-tabbed-display; }

  Mod+H { focus-column-left; }
  Mod+J { spawn "${focusVertical}/bin/focus-vertical" "down"; }
  Mod+K { spawn "${focusVertical}/bin/focus-vertical" "up"; }
  Mod+L { focus-column-right; }
  Mod+Left { focus-column-left; }
  Mod+Down { spawn "${focusVertical}/bin/focus-vertical" "down"; }
  Mod+Up { spawn "${focusVertical}/bin/focus-vertical" "up"; }
  Mod+Right { focus-column-right; }

  Mod+Alt+H { move-column-left; }
  Mod+Alt+Left { move-column-left; }
  Mod+Alt+J { move-window-down; }
  Mod+Alt+Down { move-window-down; }
  Mod+Alt+K { move-window-up; }
  Mod+Alt+Up { move-window-down; }
  Mod+Alt+L { move-column-right; }
  Mod+Alt+Right { move-window-down; }

  Mod+Shift+Left { focus-monitor-left; }
  Mod+Shift+Down { focus-monitor-down; }
  Mod+Shift+Up { focus-monitor-up; }
  Mod+Shift+Right { focus-monitor-right; }

  Mod+BracketLeft { consume-or-expel-window-left; }
  Mod+BracketRight { consume-or-expel-window-right; }

  Mod+Equal { switch-preset-column-width; }
  Mod+Minus { switch-preset-column-width-back; }
  Mod+T { switch-preset-column-width; }
  Mod+C { center-column; }

  Mod+O repeat=false hotkey-overlay-title="Overview" { toggle-overview; }
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

  Mod+Alt+1 repeat=false { move-window-to-workspace 1; }
  Mod+Alt+2 repeat=false { move-window-to-workspace 2; }
  Mod+Alt+3 repeat=false { move-window-to-workspace 3; }
  Mod+Alt+4 repeat=false { move-window-to-workspace 4; }
  Mod+Alt+5 repeat=false { move-window-to-workspace 5; }
  Mod+Alt+6 repeat=false { move-window-to-workspace 6; }
  Mod+Alt+7 repeat=false { move-window-to-workspace 7; }
  Mod+Alt+8 repeat=false { move-window-to-workspace 8; }
  Mod+Alt+9 repeat=false { move-window-to-workspace 9; }
  Mod+Alt+0 repeat=false { move-window-to-workspace 10; }

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

  Mod+WheelScrollDown cooldown-ms=140 { focus-workspace-down; }
  Mod+WheelScrollUp cooldown-ms=140 { focus-workspace-up; }

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
  XF86AudioPlay allow-when-locked=true { spawn "playerctl" "play-pause"; }
  XF86AudioPrev allow-when-locked=true { spawn "playerctl" "previous"; }
  XF86AudioNext allow-when-locked=true { spawn "playerctl" "next"; }

  Mod+Escape allow-inhibiting=false { toggle-keyboard-shortcuts-inhibit; }
''
