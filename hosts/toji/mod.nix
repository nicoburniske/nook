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
        opencode-remote
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
        secrets
        seni
        fonts
        compositor
        niri
        handy
        kitty
        keepassxc
        nautilus
        papers
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
        mullvad
        tailscale
        sunshine
        qbittorrent
        jai
      ]);
    _module.args.host = host;
    nook = {
      opencodeRemote.server.enable = true;
      seni.theme.transparency = {
        light = 0.95;
        dark = 0.95;
        darkOnLight = 0.95;
      };
      noctalia.lockscreen.output = "DP-3";
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
