{
  host,
  lib,
  pkgs,
}: let
  inherit (lib.kdl) node;

  cmd = import ./cmd.nix {
    inherit host pkgs;
  };
  focusVertical = pkgs.writeNuScriptBin "focus-vertical" {
    runtimeInputs = [pkgs.niri];
    source = ./focus-vertical.nu;
  };
  monitor = pkgs.writeNuScriptBin "monitor" {
    runtimeInputs = [pkgs.niri];
    source = ''
      def main [action: string, index: int] {
        if $index < 1 or $action not-in ["focus-monitor" "move-window-to-monitor"] {
          exit 2
        }

        let output = niri msg --json outputs
        | from json
        | values
        | where logical != null
        | sort-by name
        | get -o ($index - 1)

        if $output != null {
          niri msg action $action $output.name | ignore
        }
      }
    '';
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
in
  [
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
      key = "Mod+Alt+Ctrl+Q";
      props = {
        allow-inhibiting = false;
        hotkey-overlay-title = "Lock screen";
      };
      action = spawn ["noctalia" "msg" "session" "lock"];
    })
    (bind {
      key = "Mod+Alt+Ctrl+Shift+Q";
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
    (simple "Mod+Alt+J" "move-window-to-workspace-down")
    (simple "Mod+Alt+Down" "move-window-down")
    (simple "Mod+Alt+K" "move-window-to-workspace-up")
    (simple "Mod+Alt+Up" "move-window-up")
    (simple "Mod+Alt+L" "move-column-right")
    (simple "Mod+Alt+Right" "move-column-right")

    (simple "Mod+Alt+Ctrl+H" "move-window-to-monitor-left")
    (simple "Mod+Alt+Ctrl+Left" "move-window-to-monitor-left")
    (simple "Mod+Alt+Ctrl+J" "move-window-to-monitor-down")
    (simple "Mod+Alt+Ctrl+Down" "move-window-to-monitor-down")
    (simple "Mod+Alt+Ctrl+K" "move-window-to-monitor-up")
    (simple "Mod+Alt+Ctrl+Up" "move-window-to-monitor-up")
    (simple "Mod+Alt+Ctrl+L" "move-window-to-monitor-right")
    (simple "Mod+Alt+Ctrl+Right" "move-window-to-monitor-right")
  ]
  ++ (lib.range 1 9
    |> lib.concatMap (index: [
      (bind {
        key = "Mod+Ctrl+${toString index}";
        props.repeat = false;
        action = spawn ["${monitor}/bin/monitor" "focus-monitor" (toString index)];
      })
      (bind {
        key = "Mod+Ctrl+Alt+${toString index}";
        props.repeat = false;
        action = spawn ["${monitor}/bin/monitor" "move-window-to-monitor" (toString index)];
      })
    ]))
  ++ [
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
  ]
  ++ (lib.range 1 10
    |> lib.concatMap (workspace: let
      key =
        if workspace == 10
        then "0"
        else toString workspace;
    in [
      (bind {
        key = "Mod+${key}";
        props.repeat = false;
        action = action "focus-workspace" [workspace];
      })
      (bind {
        key = "Mod+Alt+${key}";
        props.repeat = false;
        action = action "move-window-to-workspace" [workspace];
      })
    ]))
  ++ [
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
