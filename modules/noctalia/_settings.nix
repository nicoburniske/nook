theme: let
  desktopFontSize = theme.fonts.sizes.desktop;
  uiFontScale = desktopFontSize / 11;
  barFontScale = desktopFontSize / 10;
in {
  settingsVersion = 59;

  bar = import ./_bar.nix {inherit barFontScale;};

  general = {
    radiusRatio = 0.18;
    iRadiusRatio = 0.18;
    boxRadiusRatio = 0.18;
    screenRadiusRatio = 0;
    animationSpeed = 2.0;
    animationDisabled = false;
    showScreenCorners = false;
    enableShadows = false;
    enableBlurBehind = false;
    showChangelogOnStartup = false;
  };

  ui = {
    fontDefault = theme.fonts.sansSerif.name;
    fontFixed = theme.fonts.monospace.name;
    fontDefaultScale = uiFontScale;
    fontFixedScale = uiFontScale;
    settingsPanelMode = "window";
    panelsAttachedToBar = false;
    panelBackgroundOpacity = 1.0;
    translucentWidgets = false;
    boxBorderEnabled = false;
  };

  location = {
    name = "";
    weatherEnabled = false;
    weatherShowEffects = false;
    weatherTaliaMascotAlways = false;
    showCalendarWeather = false;
    autoLocate = false;
  };

  calendar = {
    cards = [
      {
        enabled = true;
        id = "calendar-header-card";
      }
      {
        enabled = true;
        id = "calendar-month-card";
      }
      {
        enabled = false;
        id = "weather-card";
      }
    ];
  };

  appLauncher = {
    enableClipboardHistory = false;
    enableSettingsSearch = false;
    enableWindowsSearch = false;
    enableSessionSearch = false;
  };

  wallpaper = {
    enabled = false;
    fillMode = "crop";
    useSolidColor = false;
    automationEnabled = false;
    useOriginalImages = true;
  };

  idle = {
    enabled = false;
  };

  dock = {
    enabled = false;
  };

  sessionMenu = {
    enableCountdown = false;
    largeButtonsStyle = true;
    largeButtonsLayout = "single-row";
    position = "center";
    powerOptions = [
      {
        action = "lock";
        command = "hyprlock";
        enabled = true;
        keybind = "1";
      }
      {
        action = "suspend";
        enabled = true;
        keybind = "2";
      }
      {
        action = "hibernate";
        enabled = true;
        keybind = "3";
      }
      {
        action = "reboot";
        enabled = true;
        keybind = "4";
      }
      {
        action = "logout";
        enabled = true;
        keybind = "5";
      }
      {
        action = "shutdown";
        enabled = true;
        keybind = "6";
      }
      {
        action = "rebootToUefi";
        enabled = true;
        keybind = "7";
      }
    ];
  };

  notifications = {
    lowUrgencyDuration = 3;
    normalUrgencyDuration = 3;
    criticalUrgencyDuration = 3;
  };

  controlCenter = {
    cards = [
      {
        enabled = true;
        id = "profile-card";
      }
      {
        enabled = true;
        id = "shortcuts-card";
      }
      {
        enabled = true;
        id = "audio-card";
      }
      {
        enabled = false;
        id = "brightness-card";
      }
      {
        enabled = false;
        id = "weather-card";
      }
      {
        enabled = true;
        id = "media-sysmon-card";
      }
    ];
  };

  colorSchemes = {
    darkMode = true;
    schedulingMode = "manual";
    syncGsettings = false;
  };

  nightLight = {
    enabled = false;
  };
}
