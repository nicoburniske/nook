{...}: let
  mkYaziModule = {
    pkgs,
    yaziPackage,
  }: let
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
    environment.systemPackages = [yaziPackage];

    sumi.configFile = {
      "yazi/yazi.toml".value = tomlFormat.generate "sumi-yazi.toml" yaziSettings;
      "yazi/theme.toml" = {
        watch = ["theme"];
        value = ctx: tomlFormat.generate "sumi-yazi-theme-${ctx.selection.theme}.toml" (mkTheme ctx.values.theme);
      };
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
