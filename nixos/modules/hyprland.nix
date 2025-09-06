{
  config,
  pkgs,
  lib,
  ...
}: {
  home.packages = with pkgs; [
    hyprshot
    phinger-cursors
  ];

  programs.hyprlock = {
    enable = true;

    settings = {
      general = {
        hide_cursor = true;
        immediate_render = true;
        fail_timeout = 3000;
      };

      auth = {
        pam.enabled = true;
      };

      animations = {
        enabled = true;
        bezier = "linear, 1, 1, 0, 0";
        animation = [
          "fadeIn, 1, 1.5, linear"
          "fadeOut, 1, 1.5, linear"
          "inputFieldDots, 1, 2, linear"
        ];
      };

      background = {
        monitor = "";
        blur_passes = 2;
        blur_size = 4;
        noise = 0.01;
        contrast = 0.9;
        brightness = 0.8;
        vibrancy = 0.15;
      };

      # Date and time label
      label = {
        monitor = "";
        text = ''cmd[update:1000] echo "$(date +%H:%M | tr '[:upper:]' '[:lower:]')<br/><span font_size='small'>$(date '+%a %b %d' | tr '[:upper:]' '[:lower:]')</span>"'';
        text_align = "center";
        color = "rgb(${config.lib.stylix.colors.base05})";
        font_size = 48;
        font_family = config.stylix.fonts.serif.name;
        position = "0, 150";
        halign = "center";
        valign = "center";
      };

      input-field = {
        monitor = "";
        size = "400, 70";
        outline_thickness = 6;
        dots_size = 0.2;
        dots_spacing = 0.3;
        dots_center = true;
        fade_on_empty = false;
        fade_timeout = 3000;
        placeholder_text = "";
        hide_input = true;
        halign = "center";
        valign = "center";
      };
    };
  };

  wayland.windowManager.hyprland = {
    enable = true;
    # Use packages from NixOS module to avoid version conflicts
    package = null;
    portalPackage = null;

    # Import systemd environment variables for proper service integration
    systemd.variables = ["--all"];

    settings = {
      # MacBook 16 M1 Max
      monitor = [
        "eDP-1, 3456x2234@60, 0x0, 1.6"
        ", preferred, auto, 1"
      ];

      # Cursor configuration
      env = [
        "HYPRCURSOR_THEME,${
          if config.stylix.polarity == "light"
          then "phinger-cursors-dark"
          else "phinger-cursors-light"
        }"
        "HYPRCURSOR_SIZE,24"
        "XCURSOR_THEME,${
          if config.stylix.polarity == "light"
          then "phinger-cursors-dark"
          else "phinger-cursors-light"
        }"
        "XCURSOR_SIZE,24"
      ];

      xwayland.force_zero_scaling = true;

      # Allow arbitrary scaling values (disable the "clean divisor" check)
      debug = {
        disable_scale_checks = true;
      };

      exec-once = [
        "waybar"
        "hyprctl setcursor ${
          if config.stylix.polarity == "light"
          then "phinger-cursors-dark"
          else "phinger-cursors-light"
        } 24"
      ];

      "$mod" = "alt";

      bind = [
        "$mod, g, exec, ghostty"
        "$mod, t, exec, theme-switch"
        "$mod, Return, fullscreen, 1"
        "$mod, Q, killactive"
        "$mod, M, exit"
        "$mod, F, togglefloating"
        "$mod, Space, exec, walker"
        "CTRL $mod, L, exec, hyprlock"

        "$mod, P, exec, hyprshot -m output -o ~/screenshots"
        "$mod SHIFT, P, exec, hyprshot -m region -o ~/screenshots"

        ",xf86monbrightnessup, exec, brightnessctl set 5%+"
        ",xf86monbrightnessdown, exec, brightnessctl set 5%-"
        "SHIFT,xf86monbrightnessup, exec, brightnessctl --device='kbd_backlight' set 5%+"
        "SHIFT,xf86monbrightnessdown, exec, brightnessctl --device='kbd_backlight' set 5%-"
        ",xf86audioraisevolume, exec, wpctl set-volume -l 1.0 @DEFAULT_SINK@ 5%+"
        ",xf86audiolowervolume, exec, wpctl set-volume -l 1.0 @DEFAULT_SINK@ 5%-"
        ",xf86audiomute, exec, wpctl set-mute @DEFAULT_SINK@ toggle"

        "$mod, H, movefocus, l"
        "$mod, L, movefocus, r"
        "$mod, K, movefocus, u"
        "$mod, J, movefocus, d"

        "$mod, 1, workspace, 1"
        "$mod, 2, workspace, 2"
        "$mod, 3, workspace, 3"
        "$mod, 4, workspace, 4"
        "$mod, 5, workspace, 5"
        "$mod, 6, workspace, 6"
        "$mod, 7, workspace, 7"
        "$mod, 8, workspace, 8"
        "$mod, 9, workspace, 9"
        "$mod, 0, workspace, 10"

        "$mod SHIFT, 1, movetoworkspace, 1"
        "$mod SHIFT, 2, movetoworkspace, 2"
        "$mod SHIFT, 3, movetoworkspace, 3"
        "$mod SHIFT, 4, movetoworkspace, 4"
        "$mod SHIFT, 5, movetoworkspace, 5"
        "$mod SHIFT, 6, movetoworkspace, 6"
        "$mod SHIFT, 7, movetoworkspace, 7"
        "$mod SHIFT, 8, movetoworkspace, 8"
        "$mod SHIFT, 9, movetoworkspace, 9"
        "$mod SHIFT, 0, movetoworkspace, 10"
      ];

      bindm = [
        "$mod, mouse:272, movewindow"
        "$mod, mouse:273, resizewindow"
      ];

      input = {
        kb_layout = "us";
        follow_mouse = 1;
        touchpad = {
          natural_scroll = true;
          scroll_factor = 0.8;
          tap-to-click = false;
          clickfinger_behavior = 1;
        };
        sensitivity = 0;
        repeat_delay = 300;
        repeat_rate = 50;
      };

      general = {
        gaps_in = 5;
        gaps_out = 20;
        border_size = 2;
        layout = "dwindle";
        resize_on_border = true;
      };

      animations = {
        enabled = true;
        bezier = "myBezier, 0.05, 0.9, 0.1, 1.05";
        animation = [
          "windows, 1, 7, myBezier"
          "windowsOut, 1, 7, default, popin 80%"
          "border, 1, 10, default"
          "borderangle, 1, 8, default"
          "fade, 1, 7, default"
          "workspaces, 1, 6, default"
        ];
      };

      dwindle = {
        pseudotile = true;
        preserve_split = true;
      };

      misc = {
        force_default_wallpaper = -1;
      };
    };
  };
}
