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
    graphics = {
      enable = true;
      enable32Bit = true;
    };
  };

  services.xserver.videoDrivers = ["amdgpu"];

  networking = {
    hostName = host.name;
    networkmanager.enable = true;
  };

  time.timeZone = "America/New_York";
  i18n.defaultLocale = "en_US.UTF-8";

  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
  };
  security.rtkit.enable = true;

  services.printing.enable = true;
  services.udisks2.enable = true;
  services.gvfs.enable = true;
  services.upower.enable = true;
  services.power-profiles-daemon.enable = true;

  xdg.portal = {
    enable = true;
    extraPortals = with pkgs; [
      xdg-desktop-portal-gtk
      xdg-desktop-portal-gnome
    ];
  };

  programs = {
    zsh.enable = true;
    steam = {
      enable = true;
      remotePlay.openFirewall = true;
      dedicatedServer.openFirewall = true;
    };
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
