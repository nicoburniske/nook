{
  mod.nixos.spotify-web = {
    host,
    pkgs,
    ...
  }: let
    chromium = pkgs.chromium.override {
      enableWideVine = true;
    };

    spotify-web = pkgs.runCommand "spotify-web" {nativeBuildInputs = [pkgs.makeBinaryWrapper];} ''
      mkdir -p $out/bin
      makeBinaryWrapper ${chromium}/bin/chromium $out/bin/spotify-web \
        --add-flags "--user-data-dir=${host.homeDirectory}/.config/spotify-web" \
        --add-flags "--app=https://open.spotify.com"
    '';

    spotifyDesktop = pkgs.makeDesktopItem {
      name = "spotify-web";
      desktopName = "Spotify";
      genericName = "Music Player";
      exec = "${spotify-web}/bin/spotify-web";
      icon = "spotify";
      categories = ["Audio" "Music" "Player"];
    };
  in {
    nixpkgs.allowedUnfreePackages = [
      chromium
      chromium.browser
      pkgs.widevine-cdm
    ];

    environment.systemPackages = [
      spotify-web
      spotifyDesktop
    ];

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
