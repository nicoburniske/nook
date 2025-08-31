{ ... }: {
  programs.yazi = {
    enable = true;

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