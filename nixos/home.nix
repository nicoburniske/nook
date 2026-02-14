{...}: {
  imports = [];

  home.username = "nico";
  home.homeDirectory = "/home/nico";
  home.stateVersion = "24.05";

  programs.home-manager.enable = true;

  # Enable dconf for GNOME settings
  dconf.enable = true;

  home.packages = [];
}
