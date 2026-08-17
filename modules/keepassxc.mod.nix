{
  nixosModules.keepassxc = {
    compositor.niri.config = [
      {
        window-rule = {
          match."app-id" = "^org\\.keepassxc\\.KeePassXC$";
          block-out-from = "screencast";
        };
      }
    ];
  };

  homeModules.keepassxc = {pkgs, ...}: {
    packages = [pkgs.keepassxc];
  };
}
