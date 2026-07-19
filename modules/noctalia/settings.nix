{
  theme,
  lockscreen,
}: let
  desktopFontSize = theme.fonts.sizes.desktop;
  uiFontScale = desktopFontSize / 11;
  barFontScale = desktopFontSize / 10;
in {
  accessibility.ui_scale = uiFontScale;

  shell = {
    corner_radius_scale = 0.18;
    font_family = theme.fonts.sansSerif.name;
    time_format = "{:%H:%M}";
    date_format = "%A, %x";
    telemetry_enabled = false;
    clipboard_enabled = false;
    settings_show_advanced = false;
    launcher.fetch_exchange_rates = false;

    # handle desktop privilege prompts, including greeter sync
    polkit_agent = true;

    # copy wallpaper, palette, session actions, and output layout after authorization
    greeter_sync = {
      auto_sync = true;
      privilege_command = "pkexec";
    };

    animation = {
      enabled = true;
      speed = 2.0;
    };

    panel = {
      transparency_mode = "solid";
      borders = true;
      shadow = true;
      clipboard_placement = "attached";
      control_center_placement = "floating";
      wallpaper_placement = "attached";
      session_placement = "attached";
      open_near_click_clipboard = true;
      open_near_click_control_center = true;
      open_near_click_wallpaper = true;
      open_near_click_session = true;
    };
  };

  theme = {
    mode = "dark";
    source = "custom";
    custom_palette = "Nook";
  };

  wallpaper = {
    enabled = true;
    transition_duration = 500.0;
    default.path = toString theme.image;
    last.path = toString theme.image;
  };
  backdrop.enabled = false;
  dock = {
    enabled = true;
    auto_hide = true;
    reserve_space = false;
    magnification = false;
    active_scale = 1.0;
    inactive_scale = 1.0;
    launcher_position = "start";
  };
  weather.enabled = false;
  nightlight.enabled = false;

  lockscreen = {
    enabled = true;
    blur_intensity = 0.3;
    tint_intensity = 0.3;
  };

  lockscreen_widgets = {
    enabled = true;
    schema_version = 2;
    widget_order = ["time" "date"];
    widget = {
      time = {
        type = "clock";
        output = lockscreen.output;
        cx = lockscreen.logicalWidth / 2.0;
        cy = 500.0;
        box_width = 700.0;
        box_height = 180.0;
        settings = {
          background = false;
          center_text = true;
          color = "on_surface";
          font_family = theme.fonts.serif.name;
          format = "{:%H:%M}";
          shadow = true;
        };
      };
      date = {
        type = "clock";
        output = lockscreen.output;
        cx = lockscreen.logicalWidth / 2.0;
        cy = 630.0;
        box_width = 500.0;
        box_height = 64.0;
        settings = {
          background = false;
          center_text = true;
          color = "on_surface";
          font_family = theme.fonts.serif.name;
          format = "{:%a %b %d}";
          shadow = true;
        };
      };
    };
  };

  idle.behavior = {
    lock = {
      action = "lock";
      enabled = true;
      timeout = 600;
    };
    screen-off = {
      action = "screen_off";
      enabled = true;
      timeout = 660;
    };
    "lock-and-suspend" = {
      action = "lock_and_suspend";
      enabled = true;
      timeout = 3600;
    };
  };

  notification = {
    enable_daemon = true;
    position = "top_center";
    background_opacity = 1.0;
    filter."shorter notifications" = {
      match_content = ".*";
      override_duration = 4000;
    };
  };

  brightness = {
    enable_ddcutil = true;
    minimum_brightness = 0.05;
  };

  audio.enable_sounds = false;

  bar.main = {
    position = "top";
    thickness = 34;
    background_opacity = 0.0;
    radius = 0;
    radius_top_left = 0;
    radius_top_right = 0;
    radius_bottom_left = 0;
    radius_bottom_right = 0;
    margin_ends = 0;
    margin_edge = 0;
    margin_opposite_edge = 0;
    padding = 14;
    widget_spacing = 7;
    scale = barFontScale;
    shadow = true;
    reserve_space = true;
    capsule = true;
    capsule_fill = "surface";
    capsule_radius = 0.0;
    capsule_opacity = 1.0;
    capsule_border = "outline";

    start = ["workspaces"];
    center = [];
    end = [
      "tray"
      "notifications"
      "battery"
      "volume"
      "bluetooth"
      "brightness"
      "clock"
      "control-center"
    ];
  };

  widget = {
    workspaces = {
      display = "id";
      hide_when_empty = true;
      labels_only_when_occupied = true;
      focused_color = "primary";
      occupied_color = "secondary";
      empty_color = "secondary";
    };

    battery.show_label = true;
    volume.show_label = false;
    bluetooth.show_label = false;
    brightness.show_label = false;

    clock = {
      format = "{:%H:%M}";
      tooltip_format = "{:%H:%M %a, %b %d}";
    };
  };
}
