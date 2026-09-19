{inputs, ...}: {
  inputs = {
    noctalia = {
      url = "github:noctalia-dev/noctalia/v5.1.0";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    noctalia-greeter = {
      url = "github:noctalia-dev/noctalia-greeter/v1.5.0";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  nixosModules.noctalia = {
    host,
    lib,
    pkgs,
    ...
  }: let
    package = inputs.noctalia.packages.${pkgs.stdenv.hostPlatform.system}.default;
    noctalia = lib.getExe package;
  in {
    imports = [inputs.noctalia-greeter.nixosModules.default];
    options.nook.noctalia = {
      bar = {
        position = lib.mkOption {
          type = lib.types.enum ["top" "bottom" "left" "right"];
          default = "left";
        };
        thickness = lib.mkOption {
          type = lib.types.ints.positive;
          default = 28;
        };
      };
      lockscreen.output = lib.mkOption {
        type = lib.types.str;
        description = "output containing the lock screen widgets";
      };
    };
    config = {
      programs.noctalia-greeter = {
        enable = true;
        passwordless-sync-users = [host.user];
        settings = {
          session.default = "niri";
          user.default = host.user;
        };
      };
      systemd.user.services.noctalia = {
        description = "Noctalia desktop shell";
        wantedBy = ["graphical-session.target"];
        partOf = ["graphical-session.target"];
        after = ["graphical-session.target"];
        enableDefaultPath = false;
        serviceConfig = {
          ExecStart = noctalia;
          Restart = "on-failure";
        };
      };
      compositor.niri.config = [
        {
          layer-rule = {
            match.namespace = "^noctalia-wallpaper$";
            place-within-backdrop = true;
          };
        }

        {
          layer-rule = {
            match.namespace = "^noctalia-bar-";
            background-effect = [
              {blur = true;}
              {xray = false;}
            ];
          };
        }
      ];
    };
  };

  homeModules.noctalia = {
    lib,
    osConfig,
    pkgs,
    ...
  }: let
    package = inputs.noctalia.packages.${pkgs.stdenv.hostPlatform.system}.default;
    noctalia = lib.getExe package;
    settings = import ./settings.nix;
    colors = import ./colors.nix;
  in {
    packages = [
      pkgs.ddcutil
      package
    ];

    file.config = {
      "noctalia/config.toml" = {
        facet = "theme";
        value = {theme}:
          lib.toml.toTOML (settings {
            theme = theme.value;
            bar = osConfig.nook.noctalia.bar;
            lockscreen = osConfig.nook.noctalia.lockscreen;
          });
      };

      "noctalia/palettes/Nook.json" = {
        facet = "theme";
        value = {theme}: let
          palette = colors theme.value;
        in
          builtins.toJSON {
            dark = palette;
            light = palette;
          };
      };
    };

    effect.noctalia = let
      reload = pkgs.writers.writeNu "seni-noctalia" ''
        def main [wallpaper: string] {
          ^${noctalia} msg config-reload
          ^${noctalia} msg wallpaper-set $wallpaper
        }
      '';
    in {
      on = ["theme"];
      exec = {theme}: [reload theme.value.image];
      ignoreFailure = true;
    };
  };
}
