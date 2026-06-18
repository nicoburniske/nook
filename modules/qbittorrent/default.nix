{...}: {
  flake.modules.nixos.qbittorrent = {pkgs, ...}: let
    nyaasi = pkgs.fetchurl {
      url = "https://raw.githubusercontent.com/MadeOfMagicAndWires/qBit-plugins/master/engines/nyaasi.py";
      sha256 = "0ijfwhfj0j1p5iazvc4n3fk0w9hhb3amik808gbc71idsavxwf4b";
    };
  in {
    environment.systemPackages = [pkgs.qbittorrent];

    sumi.dataFile = {
      "qBittorrent/nova3/engines/nyaasi.py".value = nyaasi;
    };
  };
}
