{...}: {
  flake.mod.common.yazi = {pkgs, ...}: let
    tomlFormat = pkgs.formats.toml {};

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

    mkTheme = import ./_theme.nix;
  in {
    environment.systemPackages = [pkgs.yazi];

    sumi.configFile = {
      "yazi/yazi.toml".value = tomlFormat.generate "sumi-yazi.toml" yaziSettings;
      "yazi/theme.toml" = {
        watch = "theme";
        value = ctx: tomlFormat.generate "sumi-yazi-theme-${ctx.variant}.toml" (mkTheme ctx.value);
      };
    };
  };
}
