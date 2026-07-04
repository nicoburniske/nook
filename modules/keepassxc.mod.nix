{
  nixosModules.keepassxc = {pkgs, ...}: {
    environment.systemPackages = [pkgs.keepassxc];

    compositor.niri.config = [
      {
        window-rule = {
          match."app-id" = "^org\\.keepassxc\\.KeePassXC$";
          block-out-from = "screencast";
        };
      }
    ];
  };
}
