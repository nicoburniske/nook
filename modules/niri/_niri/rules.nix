''
  window-rule {
      geometry-corner-radius 0
      clip-to-geometry true
      draw-border-with-background false
  }

  window-rule {
      match app-id=r#"^steam$"#
      match app-id=r#"^steam_app_[0-9]+$"#
      open-on-workspace "5"
  }

  window-rule {
      match app-id=r#"^kitty$"#
      scroll-factor 1.5

      background-effect {
          blur true
      }
  }

  window-rule {
      match app-id=r#"^chrome-open\.spotify\.com__-Default$"#
      opacity 0.9

      background-effect {
          blur true
      }
  }

  window-rule {
      match app-id=r#"^org\.keepassxc\.KeePassXC$"#
      block-out-from "screencast"
  }

  window-rule {
      match app-id=r#"^pavucontrol$"#
      match app-id=r#"^nm-connection-editor$"#
      match app-id=r#"^blueman-manager$"#
      match app-id=r#"^org\.gnome\.FileRoller$"#
      open-floating true
  }

  window-rule {
      match app-id=r#"^xdg-desktop-portal-gtk$"# title=r#"^(Open File|Save File|Save As).*$"#
      match app-id=r#"^$"# title=r#"^Select what to share$"#
      open-floating true
      default-column-width { proportion 0.7; }
      default-window-height { proportion 0.7; }
  }

  window-rule {
      match app-id=r#"^org\.qbittorrent\.qBittorrent$"# title=r#"^\[.*"#
      open-floating true
      default-column-width { proportion 0.7; }
      default-window-height { proportion 0.7; }
  }

  layer-rule {
      match namespace="^awww-daemon$"

      place-within-backdrop true
  }
''
