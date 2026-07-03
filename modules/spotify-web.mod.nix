{config, ...}: {
  mod.nixos.spotify-web = {
    host,
    pkgs,
    ...
  }: {
    imports = [config.flake.nixosModules.chromium];

    environment.systemPackages = pkgs.writeChromiumApp {
      name = "spotify-web";
      url = "https://open.spotify.com";
      desktopName = "Spotify";
      icon = "spotify";
      categories = ["Audio" "Music" "Player"];
      userDataDir = "${host.homeDirectory}/.config/spotify-web";
    };

    compositor.niri.config = [
      {
        window-rule = {
          match."app-id" = "^chrome-open\\.spotify\\.com__-Default$";
          opacity = 0.9;
          background-effect = [{blur = true;}];
        };
      }
    ];
  };
}
