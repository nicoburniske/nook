{
  homeModules.yazi = {
    lib,
    pkgs,
    ...
  }: let
    yaziSettings = {
      mgr = {
        show_hidden = true;
      };

      opener = {
        edit = [
          {
            run = ''hx "$@"'';
            desc = "Edit in Helix";
            block = true;
          }
        ];

        video = [
          {
            run = ''vlc "$@"'';
            desc = "Open in VLC";
            orphan = true;
          }
        ];
      };

      tasks = {
        image_bound = [0 0];
      };

      open = {
        rules = [
          {
            mime = "text/*";
            use = "edit";
          }
          {
            mime = "application/json";
            use = "edit";
          }
          {
            mime = "application/javascript";
            use = "edit";
          }
          {
            mime = "application/toml";
            use = "edit";
          }
          {
            mime = "application/yaml";
            use = "edit";
          }
          {
            mime = "application/xml";
            use = "edit";
          }
          {
            mime = "video/*";
            use = "video";
          }
        ];
      };
    };

    mkTheme = import ./theme.nix;
  in {
    packages = [pkgs.yazi];

    zsh.interactiveShellInit = ''
      function yy() {
        local tmp="$(mktemp -t "yazi-cwd.XXXXXX")"
        yazi "$@" --cwd-file="$tmp"
        if cwd="$(cat -- "$tmp")" && [ -n "$cwd" ] && [ "$cwd" != "$PWD" ]; then
          cd -- "$cwd"
        fi
        rm -f -- "$tmp"
      }
    '';

    file.config = {
      "yazi/yazi.toml".value = lib.toml.toTOML yaziSettings;
      "yazi/theme.toml" = {
        facet = "theme";
        value = {theme}: lib.toml.toTOML (mkTheme theme.value);
      };
    };
  };
}
