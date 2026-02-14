{
  config,
  pkgs,
  ...
}: let
  tomlFormat = pkgs.formats.toml {};

  tvFilesPlugin = pkgs.callPackage ./plugins/tv-files.nix {
    mkYaziPlugin = pkgs.yaziPlugins.mkYaziPlugin;
  };

  tvTextPlugin = pkgs.callPackage ./plugins/tv-text.nix {
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

  mkTheme = import ./theme.nix;
in {
  environment.systemPackages = [pkgs.yazi];

  sumi.programs.yazi = {
    "yazi/yazi.toml".source = tomlFormat.generate "sumi-yazi.toml" yaziSettings;
    "yazi/keymap.toml".source = tomlFormat.generate "sumi-yazi-keymap.toml" yaziKeymap;
    "yazi/theme.toml".render = theme:
      tomlFormat.generate "sumi-yazi-theme-${theme.slug}.toml" (mkTheme theme);

    "yazi/plugins/tv-files.yazi".source = tvFilesPlugin;
    "yazi/plugins/tv-text.yazi".source = tvTextPlugin;

    reload = [];
  };
}
