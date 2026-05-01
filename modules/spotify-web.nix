{...}: {
  flake.modules.nixos.spotifyWeb = {pkgs, ...}: let
    chromium = pkgs.chromium.override {
      enableWideVine = true;
    };

    spotifyWeb = pkgs.writeShellScriptBin "spotify-web" ''
      exec ${chromium}/bin/chromium \
        --user-data-dir="$HOME/.config/spotify-web" \
        --app="https://open.spotify.com"
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
