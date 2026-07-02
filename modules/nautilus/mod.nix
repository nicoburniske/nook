{...}: {
  flake.mod.nixos.nautilus = {pkgs, ...}: {
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

    environment.systemPackages = with pkgs; [
      nautilus
      file-roller
    ];

    compositor.niri.rules = [
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
}
