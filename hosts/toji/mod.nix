{config, ...}: {
  configurations.nixos.toji.module = {...}: let
    host = {
      name = "toji";
      user = "nico";
      homeDirectory = "/home/nico";
      flakeRoot = "/home/nico/nook";
    };
  in {
    imports =
      [
        ./configuration.nix
      ]
      ++ (with config.flake.nixosModules; [
        nix
        nushell
        helix
        codex
        pi
        fzf
        oh-my-posh
        lazygit
        television
        bat
        btop
        git
        cargo
        yazi
        tools
        nuke-default-packages
        user
        docker
        plugdev
        android-webcam
        secrets
        seni
        fonts
        compositor
        niri
        kitty
        keepassxc
        nautilus
        vlc
        fuzzel
        noctalia
        qt
        gtk
        zsh
        helium
        spotify-web
        roam-web
        shadps4
        steam
        scd
        eden
        bitdo-controller
        kanto-ora
        coolercontrol
        mullvad
        tailscale
        sunshine
        qbittorrent
        jai
      ]);
    _module.args.host = host;
    nook = {
      seni.theme.transparency = {
        light = 1.0;
        dark = 1.0;
        darkOnLight = 1.0;
      };
      noctalia.lockscreen = {
        output = "DP-3";
        logicalWidth = 2560;
      };
    };
    compositor.niri.config = [
      {
        debug = [
          {render-drm-device = "/dev/dri/by-path/pci-0000:03:00.0-render";}
        ];
      }
      {
        output = {
          args = ["DP-3"];
          children = [
            {mode = "5120x2880@165.058";}
            {scale = 2;}
            {variable-refresh-rate = {};}
            {
              hdr = {
                props.mode = "on";
                children = [
                  {reference-luminance = 500;}
                  {sdr-saturation = 1.2;}
                  {sdr-brightness = 1.2;}
                ];
              };
            }
          ];
        };
      }
    ];
  };
}
