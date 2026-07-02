{...}: {
  flake.modules.nixos.qbittorrent = {pkgs, ...}: let
    nyaasi = pkgs.fetchurl {
      url = "https://raw.githubusercontent.com/MadeOfMagicAndWires/qBit-plugins/master/engines/nyaasi.py";
      sha256 = "0ijfwhfj0j1p5iazvc4n3fk0w9hhb3amik808gbc71idsavxwf4b";
    };
  in {
    environment.systemPackages = [pkgs.qbittorrent];

    compositor.niri.rules = [
      {
        window-rule = {
          match = {
            app-id = "^org\\.qbittorrent\\.qBittorrent$";
            title = "^\\[.*";
          };
          open-floating = true;
          default-column-width = [{proportion = 0.7;}];
          default-window-height = [{proportion = 0.7;}];
        };
      }
    ];

    sumi.dataFile = {
      "qBittorrent/nova3/engines/nyaasi.py".value = nyaasi;
    };
  };
}
