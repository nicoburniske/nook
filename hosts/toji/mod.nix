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
        sumi
        xdg
        fonts
        compositor
        niri
        greet
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
        eden
        bitdo-controller
        kanto-ora
        coolercontrol
        mullvad
        qbittorrent
        jai
      ]);

    _module.args.host = host;

    nook.sumi.theme.transparency = {
      light = 1.0;
      dark = 1.0;
      darkOnLight = 1.0;
    };

    compositor.niri.config = [
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
