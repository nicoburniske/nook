{...}: let
  mkYaziModule = {
    pkgs,
    yaziPackage,
  }: let
    tomlFormat = pkgs.formats.toml {};

    tvFilesPlugin = pkgs.callPackage ./_plugins/tv-files.nix {
      mkYaziPlugin = pkgs.yaziPlugins.mkYaziPlugin;
    };

    tvTextPlugin = pkgs.callPackage ./_plugins/tv-text.nix {
      mkYaziPlugin = pkgs.yaziPlugins.mkYaziPlugin;
    };

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

    yaziKeymap = {
      mgr.prepend_keymap = [
        {
          on = "S";
          run = "plugin tv-text";
          desc = "Find in files via Television";
        }
        {
          on = "z";
          run = "plugin tv-files";
          desc = "Find files via Television";
        }
      ];
    };

    mkTheme = import ./_theme.nix;
  in {
    environment.systemPackages = [yaziPackage];

    sumi.file = {
      "yazi/yazi.toml".source = tomlFormat.generate "sumi-yazi.toml" yaziSettings;
      "yazi/keymap.toml".source = tomlFormat.generate "sumi-yazi-keymap.toml" yaziKeymap;
      "yazi/theme.toml" = {
        dependsOn = ["theme"];
        render = ctx: tomlFormat.generate "sumi-yazi-theme-${ctx.selection.theme}.toml" (mkTheme ctx.values.theme);
      };

      "yazi/plugins/tv-files.yazi".source = tvFilesPlugin;
      "yazi/plugins/tv-text.yazi".source = tvTextPlugin;
    };
  };
in {
  flake.modules.nixos.yazi = {pkgs, ...}:
    mkYaziModule {
      inherit pkgs;
      yaziPackage = pkgs.yazi;
    };

  flake.modules.darwin.yazi = {pkgs, ...}:
    mkYaziModule {
      inherit pkgs;
      yaziPackage = pkgs.yazi;
    };
}
