{
  config,
  pkgs,
  ...
}: let
  homeDir = config.users.users.nicoburniske.home;
in {
  networking.hostName = "fuji";
  networking.computerName = "fuji";
  system.stateVersion = 4;
  system.primaryUser = "nicoburniske";
  nixpkgs.hostPlatform = "aarch64-darwin";

  nix = {
    enable = false;
    settings = {
      experimental-features = "nix-command flakes";
    };
  };

  nixpkgs.config.allowUnfree = true;

  users.users.nicoburniske = {
    name = "nicoburniske";
    home = "/Users/nicoburniske";
  };

  environment.variables = {
    XDG_CONFIG_HOME = "${homeDir}/.config";
  };

  environment.systemPackages = with pkgs; [
  ];

  homebrew = {
    enable = true;

    onActivation = {
      cleanup = "zap";
      upgrade = false;
    };

    taps = [
      "homebrew/cask"
    ];

    casks = [
      "raycast"
      "coolterm"
      "ghostty"
      "zed"
      "docker-desktop"
      "zen"
      "iina"
      "discord"
      "roam"
      "keepassxc"
      "mullvad-vpn"
      "sparrow"
      "bitcoin-core"
      "whatsapp"
      "spotify"
      "yacreader"
      "linearmouse"
      "flux-app"
      "sf-symbols"
      "hammerspoon"
    ];

    brews = [];
  };

  launchd.user.agents.hammerspoon = {
    path = [config.environment.systemPath];
    serviceConfig = {
      ProgramArguments = [
        "/Applications/Hammerspoon.app/Contents/MacOS/Hammerspoon"
        "-n"
      ];
      RunAtLoad = true;
      KeepAlive = true;
      StandardOutPath = "/tmp/hammerspoon.out.log";
      StandardErrorPath = "/tmp/hammerspoon.err.log";
    };
  };

  security = {
    pam.services.sudo_local = {
      enable = true;
      touchIdAuth = true;
    };
  };

  system.defaults = {
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
        "/Applications/Ghostty.app"
        "/Applications/Zen.app"
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

    loginwindow = {
      GuestEnabled = false;
    };

    screencapture = {
      location = "${homeDir}/Pictures/screenshots";
      type = "png";
      disable-shadow = true;
    };
  };

  programs.zsh.enable = true;
  environment.shells = [pkgs.zsh];

  fonts.packages = with pkgs; [
    nerd-fonts.jetbrains-mono
    (import ../common/berkeley-mono.nix {inherit pkgs;})
  ];
}
