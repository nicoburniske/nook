{
  homeModules.papers = {pkgs, ...}: {
    packages = [pkgs.papers];

    xdg.mime.defaultApplications = {
      "application/pdf" = ["org.gnome.Papers.desktop"];
    };
  };
}
