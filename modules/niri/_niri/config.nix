{config}: let
  startup =
    builtins.concatStringsSep "\n"
    (map (command: "spawn-at-startup \"sh\" \"-c\" ${builtins.toJSON command}") config.compositor.startupCommands);
in ''
  ${startup}

  workspace "1"
  workspace "2"
  workspace "3"
  workspace "4"
  workspace "5"

  environment {
      QT_QPA_PLATFORMTHEME "qt5ct"
      QT_STYLE_OVERRIDE "kvantum"
  }

  input {
      mod-key "Super"
      mod-key-nested "Super"

      keyboard {
          xkb {
              layout "us"
          }

          repeat-delay 225
          repeat-rate 50
      }

      touchpad {
          click-method "clickfinger"
          natural-scroll
          scroll-factor 0.5
          accel-speed 0.2
      }

      mouse {
          accel-speed 0.2
      }

      focus-follows-mouse max-scroll-amount="0%"
      workspace-auto-back-and-forth
  }

  output "eDP-1" {
      mode "3456x2234"
      scale 1.6
      focus-at-startup
  }

  output "Apple Computer Inc Studio XDR 0xAB040A5A" {
      mode "5120x2880@120.042"
      scale 2
      variable-refresh-rate
  }

  layout {
      gaps 5
      center-focused-column "on-overflow"
      always-center-single-column

      preset-column-widths {
          proportion 0.33333
          proportion 0.5
          proportion 0.66667
          proportion 1.0
      }

      default-column-width { proportion 1.0; }

      struts {
          top 10
          left 20
          right 20
          bottom 20
      }
  }

  gestures {
      hot-corners {
          off
      }
  }

  animations {
      workspace-switch {
          spring damping-ratio=1.0 stiffness=1000 epsilon=0.0001
      }

      horizontal-view-movement {
          spring damping-ratio=1.0 stiffness=850 epsilon=0.0001
      }

      window-movement {
          spring damping-ratio=1.0 stiffness=850 epsilon=0.0001
      }

      window-resize {
          spring damping-ratio=1.0 stiffness=850 epsilon=0.0001
      }

      window-open {
          duration-ms 160
          curve "ease-out-expo"
      }

      window-close {
          duration-ms 140
          curve "ease-out-quad"
      }

      overview-open-close {
          spring damping-ratio=1.0 stiffness=850 epsilon=0.0001
      }
  }

  prefer-no-csd
  screenshot-path "~/screenshots/Screenshot from %Y-%m-%d %H-%M-%S.png"

  hotkey-overlay {
      skip-at-startup
      hide-not-bound
  }

  blur {
      passes 2
      offset 3.0
      noise 0.02
      saturation 1.0
  }
''
