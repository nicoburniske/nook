{pkgs, ...}: {
  programs.yazi = {
    enable = true;

    plugins = {
      tv-text = pkgs.callPackage plugins/tv-text.nix {
        mkYaziPlugin = pkgs.yaziPlugins.mkYaziPlugin;
      };
      tv-files = pkgs.callPackage plugins/tv-files.nix {
        mkYaziPlugin = pkgs.yaziPlugins.mkYaziPlugin;
      };
    };

    keymap = {
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

    settings = {
      mgr = {
        show_hidden = true;
      };

      opener = {
        edit = [
          {
            run = "hx \"$@\"";
            desc = "Edit in Helix";
            block = true;
          }
        ];

        video = [
          {
            run = "vlc \"$@\"";
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
  };
}
