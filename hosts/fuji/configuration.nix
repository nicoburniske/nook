{
  config,
  host,
  pkgs,
  ...
}: let
  homeDir = config.users.users.${host.user}.home;
in {
  networking = {
    hostName = host.name;
    computerName = host.name;
  };

  system = {
    stateVersion = 4;
    primaryUser = host.user;
    defaults = {
      dock = {
        autohide = true;
        autohide-delay = 0.0;
        autohide-time-modifier = 0.5;
        show-recents = false;
        tilesize = 48;
        orientation = "left";
        minimize-to-application = true;

        persistent-apps = [
          "/System/Applications/Messages.app"
          "${homeDir}/Applications/Seni Apps/kitty.app"
          "${homeDir}/Applications/Seni Apps/Helium.app"
          "/Applications/Roam.app"
          "/System/Applications/Passwords.app"
          "/System/Applications/System Settings.app"
        ];
      };

      finder = {
        AppleShowAllExtensions = true;
        AppleShowAllFiles = false;
        ShowPathbar = true;
        ShowStatusBar = true;
        FXEnableExtensionChangeWarning = false;
        FXPreferredViewStyle = "Nlsv";
        _FXShowPosixPathInTitle = true;
      };

      NSGlobalDomain = {
        ApplePressAndHoldEnabled = false;
        InitialKeyRepeat = 15;
        KeyRepeat = 1;
        AppleInterfaceStyle = "Dark";
        AppleShowScrollBars = "WhenScrolling";
        NSAutomaticCapitalizationEnabled = false;
        NSAutomaticDashSubstitutionEnabled = false;
        NSAutomaticPeriodSubstitutionEnabled = false;
        NSAutomaticQuoteSubstitutionEnabled = false;
        NSAutomaticSpellingCorrectionEnabled = false;
      };

      trackpad = {
        Clicking = true;
        TrackpadRightClick = true;
        TrackpadThreeFingerDrag = true;
      };

      loginwindow.GuestEnabled = false;

      screencapture = {
        location = "${homeDir}/Pictures/screenshots";
        type = "png";
        disable-shadow = true;
      };
    };
  };
  nixpkgs.hostPlatform = "aarch64-darwin";

  nix.enable = false;

  users.users.${host.user} = {
    name = host.user;
    home = host.homeDirectory;
  };

  environment = {
    shells = [pkgs.zsh];
  };

  security.pam.services.sudo_local = {
    enable = true;
    touchIdAuth = true;
  };

  programs.zsh.enable = true;
}
