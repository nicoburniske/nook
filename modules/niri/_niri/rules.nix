[
  {
    window-rule = [
      {geometry-corner-radius = 0;}
      {clip-to-geometry = true;}
      {draw-border-with-background = false;}
    ];
  }

  {
    window-rule = [
      {match."app-id" = "^org\\.keepassxc\\.KeePassXC$";}
      {block-out-from = "screencast";}
    ];
  }

  {
    window-rule = [
      {match."app-id" = "^pavucontrol$";}
      {match."app-id" = "^nm-connection-editor$";}
      {match."app-id" = "^blueman-manager$";}
      {match."app-id" = "^org\\.gnome\\.FileRoller$";}
      {open-floating = true;}
    ];
  }

  {
    window-rule = [
      {
        match = {
          app-id = "^xdg-desktop-portal-gtk$";
          title = "^(Open File|Save File|Save As).*$";
        };
      }
      {
        match = {
          app-id = "^$";
          title = "^Select what to share$";
        };
      }
      {open-floating = true;}
      {default-column-width = [{proportion = 0.7;}];}
      {default-window-height = [{proportion = 0.7;}];}
    ];
  }
]
