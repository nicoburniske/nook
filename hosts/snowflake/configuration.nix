{
  host,
  inputs,
  pkgs,
  ...
}: let
  asahiFirmware = pkgs.requireFile {
    name = "vendorfw";
    hashMode = "recursive";
    hash = "sha256-PVDXMsHBzZ+lW+toZRFaObs760mcWw4CJTcXm2mVcsE=";
    message = "run 'nix-store --add-fixed sha256 --recursive /boot/vendorfw' to add the Asahi firmware";
  };
in {
  imports = [
    ./hardware-configuration.nix
    ./packages.nix
    inputs.apple-silicon.nixosModules.apple-silicon-support
  ];

  boot = {
    consoleLogLevel = 0;
    loader = {
      systemd-boot = {
        enable = true;
        configurationLimit = 5;
        graceful = true;
      };
      efi.canTouchEfiVariables = false;
    };
    kernelParams = ["appledrm.show_notch=1"];
    # apple silicon uses 16K pages, so we are forcing it
    # nixpkgs currently falls back to the 4K-page max
    kernel.sysctl."vm.mmap_rnd_bits" = 31;
    binfmt.emulatedSystems = ["x86_64-linux"];
  };

  hardware = {
    asahi = {
      enable = true;
      peripheralFirmwareDirectory = asahiFirmware;
      setupAsahiSound = true;
    };
    graphics.enable = true;

    bluetooth = {
      enable = true;
      powerOnBoot = true;
      settings.General = {
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
      wifi = {
        backend = "iwd";
        powersave = true;
      };
    };
  };
  time.timeZone = "America/New_York";

  services = {
    interception-tools = let
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
    udisks2.enable = true;
    gvfs.enable = true;
    upower.enable = true;
    power-profiles-daemon.enable = true;
  };

  virtualisation.libvirtd.enable = true;

  nixpkgs.allowedUnfreePackages = [asahiFirmware];

  environment.systemPackages = with pkgs; [
    git
  ];

  system = {
    extraDependencies = [asahiFirmware];
    stateVersion = "25.11";
  };
}
