{
  config,
  inputs,
  lib,
  pkgs,
}: let
  inherit (lib.kdl) node;

  cmd = import ./cmd.nix {
    inherit config inputs pkgs;
  };
  focusVertical = pkgs.writeNuScriptBin "focus-vertical" {
    runtimeInputs = [pkgs.niri];
    source = ./focus-vertical.nu;
  };

  action = name: args: node name null args {} [];
  spawn = args: action "spawn" args;
  bind = {
    key,
    props ? {},
    action ? null,
    actions ? [action],
  }:
    node key null [] props actions;
  simple = key: command:
    bind {
      inherit key;
      action = action command [];
    };
  focusWorkspace = key: workspace:
    bind {
      inherit key;
      props.repeat = false;
      action = action "focus-workspace" [workspace];
    };
  moveWindowToWorkspace = key: workspace:
    bind {
      inherit key;
      props.repeat = false;
      action = action "move-window-to-workspace" [workspace];
    };
  moveColumnToWorkspace = key: workspace:
    bind {
      inherit key;
      action = action "move-column-to-workspace" [workspace];
    };
in [
  (bind {
    key = "Mod+Return";
    props = {
      repeat = false;
      hotkey-overlay-title = "Terminal";
    };
    action = spawn ["kitty"];
  })
  (bind {
    key = "Mod+Space";
    props = {
      repeat = false;
      hotkey-overlay-title = "Launcher";
    };
    action = spawn ["fuzzel"];
  })
  (bind {
    key = "Mod+Ctrl+Space";
    props = {
      repeat = false;
      hotkey-overlay-title = "Scripts";
    };
    action = spawn ["${cmd}/bin/niri-cmd"];
  })

  (bind {
    key = "Ctrl+Alt+Super+L";
    props = {
      allow-inhibiting = false;
      hotkey-overlay-title = "Lock screen";
    };
    action = spawn ["noctalia" "msg" "session" "lock"];
  })
  (bind {
    key = "Ctrl+Alt+Super+Q";
    props.hotkey-overlay-title = "Exit niri";
    action = node "quit" null [] {skip-confirmation = true;} [];
  })
  (bind {
    key = "Mod+Q";
    props.repeat = false;
    action = action "close-window" [];
  })

  (simple "Mod+F" "maximize-column")
  (simple "Mod+G" "fullscreen-window")
  (simple "Mod+V" "toggle-window-floating")
  (simple "Mod+S" "toggle-column-tabbed-display")

  (simple "Mod+H" "focus-column-left")
  (bind {
    key = "Mod+J";
    action = spawn ["${focusVertical}/bin/focus-vertical" "down"];
  })
  (bind {
    key = "Mod+K";
    action = spawn ["${focusVertical}/bin/focus-vertical" "up"];
  })
  (simple "Mod+L" "focus-column-right")
  (simple "Mod+Left" "focus-column-left")
  (bind {
    key = "Mod+Down";
    action = spawn ["${focusVertical}/bin/focus-vertical" "down"];
  })
  (bind {
    key = "Mod+Up";
    action = spawn ["${focusVertical}/bin/focus-vertical" "up"];
  })
  (simple "Mod+Right" "focus-column-right")

  (simple "Mod+Alt+H" "move-column-left")
  (simple "Mod+Alt+Left" "move-column-left")
  (simple "Mod+Alt+J" "move-window-down")
  (simple "Mod+Alt+Down" "move-window-down")
  (simple "Mod+Alt+K" "move-window-up")
  (simple "Mod+Alt+Up" "move-window-down")
  (simple "Mod+Alt+L" "move-column-right")
  (simple "Mod+Alt+Right" "move-window-down")

  (simple "Mod+Shift+Left" "focus-monitor-left")
  (simple "Mod+Shift+Down" "focus-monitor-down")
  (simple "Mod+Shift+Up" "focus-monitor-up")
  (simple "Mod+Shift+Right" "focus-monitor-right")

  (simple "Mod+BracketLeft" "consume-or-expel-window-left")
  (simple "Mod+BracketRight" "consume-or-expel-window-right")

  (simple "Mod+Equal" "switch-preset-column-width")
  (simple "Mod+Minus" "switch-preset-column-width-back")
  (simple "Mod+T" "switch-preset-column-width")
  (simple "Mod+C" "center-column")

  (bind {
    key = "Mod+O";
    props = {
      repeat = false;
      hotkey-overlay-title = "Overview";
    };
    action = action "toggle-overview" [];
  })
  (simple "Mod+U" "focus-workspace-up")
  (simple "Mod+D" "focus-workspace-down")
  (simple "Mod+Ctrl+U" "move-column-to-workspace-up")
  (simple "Mod+Ctrl+D" "move-column-to-workspace-down")
  (simple "Mod+Shift+U" "move-workspace-up")
  (simple "Mod+Shift+D" "move-workspace-down")

  (focusWorkspace "Mod+1" 1)
  (focusWorkspace "Mod+2" 2)
  (focusWorkspace "Mod+3" 3)
  (focusWorkspace "Mod+4" 4)
  (focusWorkspace "Mod+5" 5)
  (focusWorkspace "Mod+6" 6)
  (focusWorkspace "Mod+7" 7)
  (focusWorkspace "Mod+8" 8)
  (focusWorkspace "Mod+9" 9)
  (focusWorkspace "Mod+0" 10)

  (moveWindowToWorkspace "Mod+Alt+1" 1)
  (moveWindowToWorkspace "Mod+Alt+2" 2)
  (moveWindowToWorkspace "Mod+Alt+3" 3)
  (moveWindowToWorkspace "Mod+Alt+4" 4)
  (moveWindowToWorkspace "Mod+Alt+5" 5)
  (moveWindowToWorkspace "Mod+Alt+6" 6)
  (moveWindowToWorkspace "Mod+Alt+7" 7)
  (moveWindowToWorkspace "Mod+Alt+8" 8)
  (moveWindowToWorkspace "Mod+Alt+9" 9)
  (moveWindowToWorkspace "Mod+Alt+0" 10)

  (moveColumnToWorkspace "Mod+Ctrl+1" 1)
  (moveColumnToWorkspace "Mod+Ctrl+2" 2)
  (moveColumnToWorkspace "Mod+Ctrl+3" 3)
  (moveColumnToWorkspace "Mod+Ctrl+4" 4)
  (moveColumnToWorkspace "Mod+Ctrl+5" 5)
  (moveColumnToWorkspace "Mod+Ctrl+6" 6)
  (moveColumnToWorkspace "Mod+Ctrl+7" 7)
  (moveColumnToWorkspace "Mod+Ctrl+8" 8)
  (moveColumnToWorkspace "Mod+Ctrl+9" 9)
  (moveColumnToWorkspace "Mod+Ctrl+0" 10)

  (bind {
    key = "Mod+WheelScrollDown";
    props.cooldown-ms = 140;
    action = action "focus-workspace-down" [];
  })
  (bind {
    key = "Mod+WheelScrollUp";
    props.cooldown-ms = 140;
    action = action "focus-workspace-up" [];
  })

  (simple "Mod+P" "screenshot-screen")
  (simple "Mod+Shift+P" "screenshot")
  (simple "Print" "screenshot")
  (simple "Alt+Print" "screenshot-window")
  (simple "Ctrl+Print" "screenshot-screen")

  (bind {
    key = "XF86MonBrightnessUp";
    props.allow-when-locked = true;
    action = spawn ["brightnessctl" "set" "5%+"];
  })
  (bind {
    key = "XF86MonBrightnessDown";
    props.allow-when-locked = true;
    action = spawn ["brightnessctl" "set" "5%-"];
  })
  (bind {
    key = "Shift+XF86MonBrightnessUp";
    props.allow-when-locked = true;
    action = spawn ["brightnessctl" "--device=kbd_backlight" "set" "5%+"];
  })
  (bind {
    key = "Shift+XF86MonBrightnessDown";
    props.allow-when-locked = true;
    action = spawn ["brightnessctl" "--device=kbd_backlight" "set" "5%-"];
  })

  (bind {
    key = "XF86AudioRaiseVolume";
    props.allow-when-locked = true;
    action = spawn ["wpctl" "set-volume" "-l" "1.0" "@DEFAULT_SINK@" "5%+"];
  })
  (bind {
    key = "XF86AudioLowerVolume";
    props.allow-when-locked = true;
    action = spawn ["wpctl" "set-volume" "-l" "1.0" "@DEFAULT_SINK@" "5%-"];
  })
  (bind {
    key = "XF86AudioMute";
    props.allow-when-locked = true;
    action = spawn ["wpctl" "set-mute" "@DEFAULT_SINK@" "toggle"];
  })
  (bind {
    key = "XF86AudioMicMute";
    props.allow-when-locked = true;
    action = spawn ["wpctl" "set-mute" "@DEFAULT_AUDIO_SOURCE@" "toggle"];
  })
  (bind {
    key = "XF86AudioPlay";
    props.allow-when-locked = true;
    action = spawn ["playerctl" "play-pause"];
  })
  (bind {
    key = "XF86AudioPrev";
    props.allow-when-locked = true;
    action = spawn ["playerctl" "previous"];
  })
  (bind {
    key = "XF86AudioNext";
    props.allow-when-locked = true;
    action = spawn ["playerctl" "next"];
  })

  (bind {
    key = "Mod+Escape";
    props.allow-inhibiting = false;
    action = action "toggle-keyboard-shortcuts-inhibit" [];
  })
]
