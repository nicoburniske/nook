{config, ...}: {
  nixosModules.spotify-web = {
    imports = [config.flake.nixosModules.chromium];
    compositor.niri.themedConfig = [
      (theme: {
        window-rule = {
          match."app-id" = "^chrome-open\\.spotify\\.com__-Default$";
          opacity = theme.opacity.apps;
          background-effect = [{blur = true;}];
        };
      })
    ];
  };

  homeModules.spotify-web = {
    config,
    pkgs,
    ...
  }: {
    packages = pkgs.writeChromiumApp {
      name = "spotify-web";
      url = "https://open.spotify.com";
      desktopName = "Spotify";
      icon = "spotify";
      categories = ["Audio" "Music" "Player"];
      userDataDir = "${config.path.config}/spotify-web";
    };
  };
}
