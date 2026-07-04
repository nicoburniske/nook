theme: let
  desktopFontSize = theme.fonts.sizes.desktop;
  uiFontScale = desktopFontSize / 11;
  barFontScale = desktopFontSize / 10;
in {
  shell = {
    ui_scale = uiFontScale;
    corner_radius_scale = 0.18;
    font_family = theme.fonts.sansSerif.name;
    time_format = "{:%H:%M}";
    date_format = "%A, %x";
    telemetry_enabled = false;
    clipboard_enabled = false;
    settings_show_advanced = false;

    animation = {
      enabled = true;
      speed = 2.0;
    };

    panel = {
      transparency_mode = "solid";
      borders = true;
      shadow = false;
      clipboard_placement = "attached";
      control_center_placement = "attached";
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

  idle.behavior = {
    lock.enabled = false;
    screen-off.enabled = false;
  };

  notification = {
    enable_daemon = true;
    background_opacity = 1.0;
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
    shadow = false;
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
      pill_scale = 0.7;
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
