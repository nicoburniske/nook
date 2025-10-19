{pkgs, ...}: {
  programs.yazi = {
    enable = true;

    plugins = {
      television = pkgs.callPackage plugins/television.nix {
        mkYaziPlugin = pkgs.yaziPlugins.mkYaziPlugin;
      };
      television-files = pkgs.callPackage plugins/television-files.nix {
        mkYaziPlugin = pkgs.yaziPlugins.mkYaziPlugin;
      };
    };

    keymap = {
      mgr.prepend_keymap = [
        {
          on = "S";
          run = "plugin television";
          desc = "Find in files via Television";
        }
        {
          on = "z";
          run = "plugin television-files";
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
