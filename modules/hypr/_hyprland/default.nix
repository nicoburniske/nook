{
  inputs,
  pkgs,
  ...
}: let
  keybinds = import ./_keybinds.nix;

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
    + " || true; ${pkgs.systemd}/bin/systemctl --user start compositor-session.target";

  mkBindLines = prefix: entries:
    builtins.concatStringsSep "\n" (map (entry: "${prefix}=${entry}") entries);

  themeSwitch = import (inputs.self + "/common/theme-switch.nix") {inherit pkgs;};
  chromiumProfile = import (inputs.self + "/common/chromium-profile.nix") {inherit pkgs;};
  workspaceLayoutToggle = pkgs.writeNuScriptBin "hypr-workspace-layout-toggle" ''
    let active = (hyprctl activeworkspace -j | from json)
    let workspace = $active.id
    let currentLayout = (($active.tiledLayout? | default "") | str downcase)
    let nextLayout = if $currentLayout == "dwindle" { "scrolling" } else { "dwindle" }
    hyprctl keyword workspace $"($workspace),layout:($nextLayout)" | ignore
  '';
in {
  nixpkgs.overlays = [
    (final: prev: {
      hyprland =
        (prev.hyprland).overrideAttrs
        (old: {
          patches =
            (old.patches or [])
            ++ [
              ./patches/force-vertical-workspace-swipe.patch
              ./patches/scrolling-swipe-gesture.patch
            ];
        });
    })
  ];

  programs.hyprland.package = pkgs.hyprland;

  environment.systemPackages = [
    themeSwitch
    chromiumProfile
    workspaceLayoutToggle
  ];

  sumi.configFile = {
    "hypr/hyprland.conf" = {
      watch = ["theme"];
      value = ctx: let
        theme = ctx.values.theme;
        t = import ./_theme.nix theme;
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
          animation=workspaces, 0, 0, ease
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

        scrolling {
          column_width=1
          explicit_column_widths=0.333, 0.5, 0.667, 1.0
          focus_fit_method=1
          follow_focus=true
        }

        general {
          border_size=2
          col.active_border=${t.general.activeBorder}
          col.inactive_border=${t.general.inactiveBorder}
          gaps_in=5
          gaps_out=10,20,20,20
          layout=scrolling
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
          disable_autoreload=true
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
        gesture=3, horizontal, scrolling
        gesture=3, vertical, workspace
        layerrule=no_anim on, match:namespace fuzzel

        monitor=eDP-1, 3456x2234@120, 0x0, 1.6
        monitor=, preferred, auto, 1

        windowrule=scroll_touchpad 1.5, match:class kitty
      '';
    };
  };

  sumi.hook.hyprland = {
    watch = ["theme"];
    command = "${pkgs.hyprland}/bin/hyprctl reload";
  };
}
