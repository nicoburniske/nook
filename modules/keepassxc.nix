{...}: {
  flake.modules.nixos.keepassxc = {pkgs, ...}: {
    environment.systemPackages = [pkgs.keepassxc];

    compositor.niri.rules = [
      {
        window-rule = {
          match."app-id" = "^org\\.keepassxc\\.KeePassXC$";
          block-out-from = "screencast";
        };
      }
    ];
  };
}
