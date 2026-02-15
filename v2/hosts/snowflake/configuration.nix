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

  nix.settings.experimental-features = ["nix-command" "flakes"];

  imports = [
    ./hardware-configuration.nix
    apple-silicon.nixosModules.apple-silicon-support

    ../../../nixos/modules/helix
    ../../../nixos/modules/fzf.nix
    ../../../nixos/modules/bat.nix
    ../../../nixos/modules/btop.nix
    ../../../nixos/modules/comically.nix
    ../../../nixos/modules/gtk
    ../../../nixos/modules/hypr
    ../../../nixos/modules/kitty
    ../../../nixos/modules/lazygit.nix
    ../../../nixos/modules/oh-my-posh.nix
    ../../../nixos/modules/opencode.nix
    ../../../nixos/modules/packages.nix
    ../../../nixos/modules/quickshell
    ../../../nixos/modules/rofi.nix
    ../../../nixos/modules/swaync
    ../../../nixos/modules/television.nix
    ../../../nixos/modules/zsh.nix
    ../../../nixos/modules/yazi
  ];

  nixpkgs.config.allowUnfree = true;

  nixpkgs.overlays = [
    (final: prev: {
      ungoogled-chromium = prev.ungoogled-chromium.override {enableWideVine = true;};

      writeNuScriptBin = name: text:
        prev.writeTextFile {
          inherit name;
          executable = true;
          destination = "/bin/${name}";
          text = ''
            #!${final.nushell}/bin/nu
            ${text}
          '';
          meta.mainProgram = name;
        };
    })
  ];

  boot = {
    consoleLogLevel = 0;
    loader.systemd-boot.enable = true;
    loader.efi.canTouchEfiVariables = false;
    kernelParams = ["appledrm.show_notch=1"];
    binfmt.emulatedSystems = ["x86_64-linux"];
  };

  hardware = {
    asahi = {
      peripheralFirmwareDirectory = ../../../nixos/firmware;
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

  services.udev = {
    enable = true;
    extraRules = ''
      SUBSYSTEMS=="usb", ATTRS{idVendor}=="10c4", ATTRS{idProduct}=="ea60", GROUP="plugdev", MODE="0666"
      SUBSYSTEMS=="usb", ATTRS{idVendor}=="1307", ATTRS{idProduct}=="0165", GROUP="plugdev", MODE="0666"
      SUBSYSTEMS=="usb", ATTRS{idVendor}=="03eb", ATTRS{idProduct}=="6124", GROUP="plugdev", MODE="0666"
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

  users.extraGroups = {
    plugdev = {};
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
      "plugdev"
      "kvm"
      "adbusers"
    ];
    shell = pkgs.zsh;
  };

  programs = {
    hyprland.enable = true;
    zsh.enable = true;
  };

  environment.systemPackages = with pkgs; [
    git
  ];

  system.stateVersion = "25.11";
}
