# Edit this configuration file to define what should be installed on
# your system. Help is available in the configuration.nix(5) man page, on
# https://search.nixos.org/options and in the NixOS manual (`nixos-help`).
{
  config,
  inputs,
  lib,
  pkgs,
  apple-silicon,
  ...
}: let
  self = inputs.self;
  shortRev = self.shortRev or self.dirtyShortRev or "unknown";
  rev = "${shortRev}-${self.lastModifiedDate}";

  themeDefinitions = import ../common/stylix.nix {inherit pkgs lib;};
  velumThemes = builtins.listToAttrs (
    map (theme: {
      name = theme.stylix.override.slug;
      value = {stylix = theme.stylix;};
    })
    themeDefinitions.themes
  );
in {
  system.configurationRevision = shortRev;
  system.nixos.label = rev;

  # Enable flakes
  nix.settings.experimental-features = ["nix-command" "flakes"];

  imports = [
    # Include the results of the hardware scan.
    ./hardware-configuration.nix
    apple-silicon.nixosModules.apple-silicon-support

    ./modules/helix
    ./modules/fzf.nix
    ./modules/bat.nix
    ./modules/btop.nix
    ./modules/hypr
    ./modules/kitty
    ./modules/lazygit.nix
    ./modules/oh-my-posh.nix
    ./modules/opencode.nix
    ./modules/quickshell
    ./modules/rofi.nix
    ./modules/swaync
    ./modules/yazi
  ];

  velum = {
    enable = true;
    user = "nico";
    flakeRoot = "/home/nico/nook";
    defaultTheme = "gruvbox";
    themes = velumThemes;
  };

  boot = {
    consoleLogLevel = 0;
    loader.systemd-boot.enable = true;
    loader.efi.canTouchEfiVariables = false;
    kernelParams = ["apple_dcp.show_notch=1"];
    binfmt.emulatedSystems = ["x86_64-linux"];
  };

  hardware = {
    asahi = {
      peripheralFirmwareDirectory = ./firmware;
      setupAsahiSound = true;
    };
    graphics.enable = true;

    bluetooth.enable = true;
    bluetooth.powerOnBoot = true;
    bluetooth.settings = {
      General = {
        Enable = "Source,Sink,Media,Socket";
        Experimental = true;
      };
    };
    keyboard.zsa.enable = true;
  };

  networking = {
    hostName = "snowflake";
    nameservers = ["1.1.1.1" "9.9.9.9"];
    wireless.iwd = {
      enable = true;
      settings.General.EnableNetworkConfiguration = true;
    };
    networkmanager = {
      enable = true;
      wifi.backend = "iwd";
      wifi.powersave = true;
    };
  };
  time.timeZone = "America/New_York";

  # Configure network proxy if necessary
  # networking.proxy.default = "http://user:password@proxy:port/";
  # networking.proxy.noProxy = "127.0.0.1,localhost,internal.domain";

  # Select internationalisation properties.
  # i18n.defaultLocale = "en_US.UTF-8";
  # console = {
  #   font = "Lat2-Terminus16";
  #   keyMap = "us";
  #   useXkbConfig = true; # use xkb.options in tty.
  # };

  # Enable the X11 windowing system.
  # services.xserver.enable = true;

  services.interception-tools = let
    itools = pkgs.interception-tools;
    itools-caps = pkgs.interception-tools-plugins.caps2esc;
  in {
    enable = true;
    plugins = [itools-caps];
    udevmonConfig = ''
      - JOB: "${itools}/bin/intercept -g $DEVNODE | ${itools-caps}/bin/caps2esc -m 1 | ${itools}/bin/uinput -d $DEVNODE"
        DEVICE:
          EVENTS:
            EV_KEY: [KEY_CAPSLOCK, KEY_ESC]
    '';
  };

  services.udev = {
    enable = true;
    extraRules = ''
      # Silicon Labs CP210x UART Bridge (debug board)
      SUBSYSTEMS=="usb", ATTRS{idVendor}=="10c4", ATTRS{idProduct}=="ea60", GROUP="plugdev", MODE="0666"
      # Transcend Information, Inc. 2GB/4GB/8GB Flash Drive (Passport Prime in normal mode)
      SUBSYSTEMS=="usb", ATTRS{idVendor}=="1307", ATTRS{idProduct}=="0165", GROUP="plugdev", MODE="0666"
      # Atmel Corp. at91sam SAMBA bootloader (Passport Prime in sam-ba mode)
      SUBSYSTEMS=="usb", ATTRS{idVendor}=="03eb", ATTRS{idProduct}=="6124", GROUP="plugdev", MODE="0666"
    '';
    # packages = with pkgs; [
    #   segger-jlink
    # ];
  };

  services.udisks2.enable = true;
  services.gvfs.enable = true;
  services.upower.enable = true;
  services.power-profiles-daemon.enable = true;

  services.mullvad-vpn = {
    enable = true;
    package = pkgs.mullvad-vpn;
  };

  virtualisation.libvirtd.enable = true;

  # Enable CUPS to print documents.
  # services.printing.enable = true;

  users.extraGroups = {
    plugdev = {};
  };

  # Define a user account. Don't forget to set a password with 'passwd'.
  users.users.nico = {
    isNormalUser = true;
    extraGroups = [
      "wheel"
      "audio"
      "video"
      "render"
      "input"
      "networkmanager"
      "users"
      "plugdev"

      "kvm"
      "adbusers"
    ];
    shell = pkgs.zsh;
  };

  programs = {
    adb.enable = true;
    hyprland.enable = true;
    zsh.enable = true;
  };

  velum.programs.ghostty = {
    "ghostty/config".render = theme: let
      c = theme.colors;
      h = c.withHashtag;
    in ''
      shell-integration-features = no-cursor,no-title
      gtk-titlebar = false
      gtk-single-instance = true
      adjust-cursor-thickness = 5
      window-theme = auto
      window-decoration = none
      window-padding-balance = true
      window-padding-x = 5
      window-padding-y = 0
      window-padding-color = extend
      scrollback-limit = 104857600
      keybind = shift+enter=text:\n
      keybind = performable:ctrl+c=copy_to_clipboard
      keybind = performable:ctrl+v=paste_from_clipboard

      background = ${c.base00}
      foreground = ${c.base05}
      cursor-color = ${c.base05}
      selection-background = ${c.base02}
      selection-foreground = ${c.base05}

      palette = 0=${h.base00}
      palette = 1=${h.base08}
      palette = 2=${h.base0B}
      palette = 3=${h.base0A}
      palette = 4=${h.base0D}
      palette = 5=${h.base0E}
      palette = 6=${h.base0C}
      palette = 7=${h.base05}
      palette = 8=${h.base03}
      palette = 9=${h.base08}
      palette = 10=${h.base0B}
      palette = 11=${h.base0A}
      palette = 12=${h.base0D}
      palette = 13=${h.base0E}
      palette = 14=${h.base0C}
      palette = 15=${h.base07}
    '';

    reload = "${pkgs.procps}/bin/pkill -SIGUSR2 ghostty || true";
  };

  # List packages installed in system profile.
  # Keep only system-level packages here, user packages go in home.nix
  environment.systemPackages = with pkgs; [
    git
    ghostty
  ];

  # Some programs need SUID wrappers, can be configured further or are
  # started in user sessions.
  # programs.mtr.enable = true;
  # programs.gnupg.agent = {
  #   enable = true;
  #   enableSSHSupport = true;
  # };

  # List services that you want to enable:

  # Enable the OpenSSH daemon.
  # services.openssh.enable = true;

  # Open ports in the firewall.
  # networking.firewall.allowedTCPPorts = [ ... ];
  # networking.firewall.allowedUDPPorts = [ ... ];
  # Or disable the firewall altogether.
  # networking.firewall.enable = false;

  # Copy the NixOS configuration file and link it from the resulting system
  # (/run/current-system/configuration.nix). This is useful in case you
  # accidentally delete configuration.nix.
  # system.copySystemConfiguration = true;

  # This option defines the first version of NixOS you have installed on this particular machine,
  # and is used to maintain compatibility with application data (e.g. databases) created on older NixOS versions.
  #
  # Most users should NEVER change this value after the initial install, for any reason,
  # even if you've upgraded your system to a new NixOS release.
  #
  # This value does NOT affect the Nixpkgs version your packages and OS are pulled from,
  # so changing it will NOT upgrade your system - see https://nixos.org/manual/nixos/stable/#sec-upgrading for how
  # to actually do that.
  #
  # This value being lower than the current NixOS release does NOT mean your system is
  # out of date, out of support, or vulnerable.
  #
  # Do NOT change this value unless you have manually inspected all the changes it would make to your configuration,
  # and migrated your data accordingly.
  #
  # For more information, see `man configuration.nix` or https://nixos.org/manual/nixos/stable/options#opt-system.stateVersion .
  system.stateVersion = "25.11"; # Did you read the comment?
}
