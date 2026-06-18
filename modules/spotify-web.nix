{...}: {
  flake.modules.nixos.spotifyWeb = {
    host,
    pkgs,
    ...
  }: let
    chromium = pkgs.chromium.override {
      enableWideVine = true;
    };

    spotifyWeb = pkgs.runCommand "spotify-web" {nativeBuildInputs = [pkgs.makeBinaryWrapper];} ''
      mkdir -p $out/bin
      makeBinaryWrapper ${chromium}/bin/chromium $out/bin/spotify-web \
        --add-flags "--user-data-dir=${host.homeDirectory}/.config/spotify-web" \
        --add-flags "--app=https://open.spotify.com"
    '';

    spotifyDesktop = pkgs.makeDesktopItem {
      name = "spotify-web";
      desktopName = "Spotify";
      genericName = "Music Player";
      exec = "${spotifyWeb}/bin/spotify-web";
      icon = "spotify";
      categories = ["Audio" "Music" "Player"];
    };
  in {
    environment.systemPackages = [
      spotifyWeb
      spotifyDesktop
    ];
  };
}
