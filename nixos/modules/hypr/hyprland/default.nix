{pkgs, ...}: let
  keybinds = import ./keybinds.nix;

  systemdVariables = [
    "DISPLAY"
    "HYPRLAND_INSTANCE_SIGNATURE"
    "WAYLAND_DISPLAY"
    "XDG_CURRENT_DESKTOP"
  ];

  systemdActivation =
    "${pkgs.systemd}/bin/systemctl --user import-environment "
    + builtins.concatStringsSep " " systemdVariables
    + "; ${pkgs.dbus}/bin/dbus-update-activation-environment --systemd "
    + builtins.concatStringsSep " " systemdVariables
    + " || true; ${pkgs.systemd}/bin/systemctl --user start hyprland-session.target";

  mkBindLines = prefix: entries:
    builtins.concatStringsSep "\n" (builtins.map (entry: "${prefix}=${entry}") entries);

  themeSwitch = import ./scripts/theme-switch.nix {inherit pkgs;};
  chromiumProfile = import ./scripts/chromium-profile.nix {inherit pkgs;};
in {
  environment.systemPackages = [
    themeSwitch
    chromiumProfile
  ];

  sumi.file = {
    "hypr/hyprland.conf" = {
      dependsOn = ["theme"];
      render = ctx: let
        theme = ctx.values.theme;
        t = import ./theme.nix theme;
        cursorTheme =
          if theme.polarity == "light"
          then "phinger-cursors-dark"
          else "phinger-cursors-light";
      in ''
        exec-once = ${systemdActivation}
        $mod=SUPER

        animations {
          bezier=easeOutQuint, 0.23, 1, 0.32, 1
          bezier=easeInOutCubic, 0.65, 0.05, 0.36, 1
          bezier=linear, 0, 0, 1, 1
          bezier=almostLinear, 0.5, 0.5, 0.75, 1.0
          bezier=quick, 0.15, 0, 0.1, 1
          animation=global, 1, 10, default
          animation=border, 1, 5.39, easeOutQuint
          animation=windows, 1, 4.79, easeOutQuint
          animation=windowsIn, 1, 4.1, easeOutQuint, popin 87%
          animation=windowsOut, 1, 1.49, linear, popin 87%
          animation=fadeIn, 1, 1.73, almostLinear
          animation=fadeOut, 1, 1.46, almostLinear
          animation=fade, 1, 3.03, quick
          animation=layers, 1, 3.81, easeOutQuint
          animation=layersIn, 1, 4, easeOutQuint, fade
          animation=layersOut, 1, 1.5, linear, fade
          animation=fadeLayersIn, 1, 1.79, almostLinear
          animation=fadeLayersOut, 1, 1.39, almostLinear
          animation=workspaces, 0, 1, default
          enabled=true
        }

        debug {
          disable_scale_checks=true
        }

        decoration {
          blur {
            enabled=true
            ignore_opacity=true
            new_optimizations=true
            passes=2
            size=8
            xray=true
          }

          shadow {
            color=${t.decorationShadowColor}
          }
        }

        dwindle {
          preserve_split=true
          pseudotile=true
        }

        general {
          border_size=2
          col.active_border=${t.general.activeBorder}
          col.inactive_border=${t.general.inactiveBorder}
          gaps_in=5
          gaps_out=10,20,20,20
          layout=dwindle
          resize_on_border=true
        }

        group {
          groupbar {
            col.active=${t.group.groupbar.active}
            col.inactive=${t.group.groupbar.inactive}
            text_color=${t.group.groupbar.textColor}
          }
          col.border_active=${t.group.borderActive}
          col.border_inactive=${t.group.borderInactive}
          col.border_locked_active=${t.group.borderLockedActive}
        }

        input {
          touchpad {
            clickfinger_behavior=1
            natural_scroll=true
            scroll_factor=0.500000
            tap-to-click=false
          }
          follow_mouse=1
          kb_layout=us
          repeat_delay=225
          repeat_rate=50
          sensitivity=0.200000
        }

        misc {
          background_color=${t.miscBackgroundColor}
          disable_hyprland_logo=true
          force_default_wallpaper=-1
        }

        xwayland {
          force_zero_scaling=true
        }

        ${mkBindLines "bind" keybinds.bind}
        ${mkBindLines "bindm" keybinds.bindm}

        env=HYPRCURSOR_THEME,${cursorTheme}
        env=HYPRCURSOR_SIZE,24
        env=XCURSOR_THEME,${cursorTheme}
        env=XCURSOR_SIZE,24

        exec=hyprctl setcursor ${cursorTheme} 24
        gesture=3, horizontal, workspace,
        layerrule=no_anim on, match:namespace rofi

        monitor=eDP-1, 3456x2234@60, 0x0, 1.6
        monitor=, preferred, auto, 1

        windowrule=scroll_touchpad 1.5, match:class kitty
      '';
    };
  };

  sumi.program.hyprland.reload = "${pkgs.hyprland}/bin/hyprctl reload || true";
}
