{
  config,
  host,
  inputs,
  pkgs,
  ...
}: let
  self = inputs.self;
  shortRev = self.shortRev or self.dirtyShortRev or "unknown";
  rev = "${shortRev}-${self.lastModifiedDate}";
in {
  system.configurationRevision = shortRev;
  system.nixos.label = rev;

  imports = [
    ./hardware-configuration.nix
    ./packages.nix
  ];

  nix = {
    settings.experimental-features = ["nix-command" "flakes"];
    gc = {
      automatic = true;
      dates = "weekly";
      options = "--delete-older-than 7d";
    };
  };

  nixpkgs.config.allowUnfree = true;

  boot = {
    loader.systemd-boot.enable = true;
    loader.efi.canTouchEfiVariables = true;
    kernelPackages = pkgs.linuxPackages_latest;
    initrd.kernelModules = ["amdgpu"];
  };

  hardware = {
    enableRedistributableFirmware = true;
    bluetooth.enable = true;
    bluetooth.powerOnBoot = true;
    bluetooth.settings = {
      General = {
        Enable = "Source,Sink,Media,Socket";
        Experimental = true;
      };
    };
    graphics = {
      enable = true;
      enable32Bit = true;
    };
    amdgpu.overdrive.enable = true;
  };

  services.xserver.videoDrivers = ["amdgpu"];

  networking = {
    hostName = host.name;
    networkmanager.enable = true;
  };

  time.timeZone = "America/New_York";
  i18n.defaultLocale = "en_US.UTF-8";

  security.rtkit.enable = true;

  services = {
    pipewire = {
      enable = true;
      alsa.enable = true;
      alsa.support32Bit = true;
      pulse.enable = true;
      wireplumber.enable = true;
    };
    printing.enable = true;
    udisks2.enable = true;
    gvfs.enable = true;
    upower.enable = true;
    power-profiles-daemon.enable = true;
    lact.enable = true;
  };

  xdg.portal = {
    enable = true;
    extraPortals = with pkgs; [
      xdg-desktop-portal-gtk
      xdg-desktop-portal-gnome
    ];
  };

  programs = {
    coolercontrol.enable = true;
    zsh.enable = true;
  };

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
    ];
    shell = pkgs.zsh;
  };

  environment.systemPackages = with pkgs; [
    git
  ];

  system.stateVersion = "25.11";
}
