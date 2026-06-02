{
  config,
  host,
  inputs,
  lib,
  pkgs,
  apple-silicon,
  ...
}: let
  self = inputs.self;
  shortRev = self.shortRev or self.dirtyShortRev or "unknown";
  rev = "${shortRev}-${self.lastModifiedDate}";
in {
  system.configurationRevision = shortRev;
  system.nixos.label = rev;

  nix = {
    settings.experimental-features = ["nix-command" "flakes"];
    gc = {
      automatic = true;
      dates = "weekly";
      options = "--delete-older-than 7d";
    };
  };

  imports = [
    ./hardware-configuration.nix
    ./packages.nix
    apple-silicon.nixosModules.apple-silicon-support
  ];

  nixpkgs.config.allowUnfree = true;

  boot = {
    consoleLogLevel = 0;
    loader.systemd-boot = {
      enable = true;
      configurationLimit = 5;
    };
    loader.efi.canTouchEfiVariables = false;
    kernelParams = ["appledrm.show_notch=1"];
    # apple silicon uses 16K pages, so we are forcing it
    # nixpkgs currently falls back to the 4K-page max
    kernel.sysctl."vm.mmap_rnd_bits" = 31;
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
    hostName = host.name;
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

  services.udisks2.enable = true;
  services.gvfs.enable = true;
  services.upower.enable = true;
  services.power-profiles-daemon.enable = true;

  services.mullvad-vpn = {
    enable = true;
    package = pkgs.mullvad-vpn;
  };

  virtualisation.libvirtd.enable = true;

  users.users.${host.user} = {
    isNormalUser = true;
    home = host.homeDirectory;
    extraGroups = [
      "wheel"
      "audio"
      "video"
      "render"
      "input"
      "networkmanager"
      "users"
      "kvm"
      "adbusers"
    ];
    shell = pkgs.zsh;
  };

  programs = {
    zsh.enable = true;
  };

  environment.systemPackages = with pkgs; [
    git
  ];

  system.stateVersion = "25.11";
}
