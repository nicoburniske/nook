{
  config,
  inputs,
  pkgs,
  ...
}: let
  keybinds = import ./_keybinds.nix;
  shellCommand = config.compositor.shell.command;

  systemdVariables = [
    "DISPLAY"
    "NIRI_SOCKET"
    "WAYLAND_DISPLAY"
    "XDG_CURRENT_DESKTOP"
    "XDG_SESSION_TYPE"
  ];

  systemdActivation =
    "${pkgs.systemd}/bin/systemctl --user import-environment "
    + builtins.concatStringsSep " " systemdVariables
    + "; ${pkgs.dbus}/bin/dbus-update-activation-environment --systemd "
    + builtins.concatStringsSep " " systemdVariables
    + " || true; ${pkgs.systemd}/bin/systemctl --user start compositor-session.target";

  mkBindLines = entries:
    builtins.concatStringsSep "\n" (map (entry: "    ${entry}") entries);

  themeSwitch = import (inputs.self + "/common/theme-switch.nix") {inherit pkgs;};
  heliumPackage = pkgs.helium;
  heliumProfile = import (inputs.self + "/common/helium-profile.nix") {inherit heliumPackage pkgs;};
in {
  environment.systemPackages = [
    themeSwitch
    heliumProfile
  ];

  sumi.configFile = {
    "niri/config.kdl.local".value = "\n";

    "niri/config.kdl" = {
      watch = ["theme"];
      value = ctx: let
        theme = ctx.values.theme;
        t = import ./_theme.nix theme;
        cursorTheme =
          if theme.polarity == "light"
          then "phinger-cursors-dark"
          else "phinger-cursors-light";
      in ''
                spawn-at-startup "sh" "-c" "${systemdActivation}"
                spawn-at-startup "${shellCommand}"

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

                layout {
                    gaps 5
                    center-focused-column "on-overflow"
                    always-center-single-column
                    background-color "${t.layout.background}"

                    preset-column-widths {
                        proportion 0.33333
                        proportion 0.5
                        proportion 0.66667
                    }

                    default-column-width { proportion 0.5; }

                    preset-window-heights {
                        proportion 0.33333
                        proportion 0.5
                        proportion 0.66667
                    }

                    focus-ring {
                        width 2
                        active-color "${t.layout.focusActive}"
                        inactive-color "${t.layout.focusInactive}"
                        urgent-color "${t.layout.focusUrgent}"
                    }

                    border {
                        off
                        width 2
                        active-color "${t.layout.borderActive}"
                        inactive-color "${t.layout.borderInactive}"
                        urgent-color "${t.layout.focusUrgent}"
                    }

                    shadow {
                        on
                        softness 24
                        spread 3
                        offset x=0 y=5
                        color "${t.layout.shadow}"
                        inactive-color "${t.layout.shadowInactive}"
                    }

                    tab-indicator {
                        hide-when-single-tab
                        place-within-column
                        gap 5
                        width 3
                        length total-proportion=1.0
                        position "right"
                        gaps-between-tabs 2
                        corner-radius 8
                        active-color "${t.layout.tabActive}"
                        inactive-color "${t.layout.tabInactive}"
                        urgent-color "${t.layout.tabUrgent}"
                    }

                    insert-hint {
                        color "${t.layout.insertHint}"
                    }

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

                cursor {
                    xcursor-theme "${cursorTheme}"
                    xcursor-size 24
                    hide-when-typing
                    hide-after-inactive-ms 2500
                }

                hotkey-overlay {
                    skip-at-startup
                    hide-not-bound
                }

                overview {
                    zoom 0.55
                    backdrop-color "${t.layout.backdrop}"
                }

                window-rule {
                    geometry-corner-radius 8
                    clip-to-geometry true
                }

                window-rule {
                    match app-id=r#"^kitty$"#
                    scroll-factor 1.5
                }

                window-rule {
                    match app-id=r#"^org\.keepassxc\.KeePassXC$"#
                    block-out-from "screencast"
                }

                window-rule {
                    match app-id=r#"^pavucontrol$"#
                    match app-id=r#"^nm-connection-editor$"#
                    match app-id=r#"^blueman-manager$"#
                    open-floating true
                }

                binds {
        ${mkBindLines keybinds}
                }

                include "config.kdl.local"
      '';
    };
  };
}
