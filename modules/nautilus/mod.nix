{
  nixosModules.nautilus = {
    nixpkgs.overlays = [
      (final: prev: {
        nautilus = prev.nautilus.overrideAttrs (old: {
          patches =
            (old.patches or [])
            ++ [
              ./theme-reload.patch
            ];
        });
      })
    ];

    compositor.niri.config = [
      {
        window-rule = {
          match."app-id" = "^org\\.gnome\\.FileRoller$";
          open-floating = true;
        };
      }

      {
        window-rule = {
          match."app-id" = "^org\\.gnome\\.Nautilus$";
          opacity = 0.9;
          background-effect = [{blur = true;}];
        };
      }
    ];
  };

  homeModules.nautilus = {pkgs, ...}: {
    packages = with pkgs; [
      nautilus
      file-roller
    ];
  };
}
