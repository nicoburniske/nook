{
  homeModules.qbittorrent = {pkgs, ...}: let
    # 2.0.15 fixes vpn interface binding on arm64 systems with 16k pages
    # https://github.com/arvidn/libtorrent/pull/8820
    libtorrent-rasterbar = pkgs.libtorrent-rasterbar.overrideAttrs {
      version = "2.0.15";
      src = pkgs.fetchFromGitHub {
        owner = "arvidn";
        repo = "libtorrent";
        rev = "1eb18faeae156d8dbbab42935c082f8b81f50989";
        hash = "sha256-5ntJQmNj+2cQJXbsJwdeT4styMYU6jT5PwtlpaDNw6w=";
        fetchSubmodules = true;
      };
    };
    qbittorrent = pkgs.qbittorrent.override {inherit libtorrent-rasterbar;};
    nyaasi = pkgs.fetchurl {
      url = "https://raw.githubusercontent.com/MadeOfMagicAndWires/qBit-plugins/master/engines/nyaasi.py";
      sha256 = "0ijfwhfj0j1p5iazvc4n3fk0w9hhb3amik808gbc71idsavxwf4b";
    };
  in {
    packages = [qbittorrent];
    file.data."qBittorrent/nova3/engines/nyaasi.py" = {value = nyaasi;};
  };

  nixosModules.qbittorrent = {
    compositor.niri.config = [
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
  };
}
