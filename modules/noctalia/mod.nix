{inputs, ...}: {
  inputs = {
    noctalia = {
      url = "github:noctalia-dev/noctalia";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    noctalia-greeter = {
      url = "github:noctalia-dev/noctalia-greeter";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  nixosModules.noctalia = {
    config,
    host,
    lib,
    pkgs,
    ...
  }: let
    cfg = config.nook.noctalia;
    package = inputs.noctalia.packages.${pkgs.stdenv.hostPlatform.system}.default;
    noctalia = lib.getExe package;
    settings = import ./settings.nix;
    colors = import ./colors.nix;
  in {
    imports = [inputs.noctalia-greeter.nixosModules.default];

    options.nook.noctalia.lockscreen = {
      output = lib.mkOption {
        type = lib.types.str;
        description = "output containing the lock screen widgets";
      };

      logicalWidth = lib.mkOption {
        type = lib.types.ints.positive;
        description = "logical width used to center lock screen widgets";
      };
    };

    config = {
      programs.noctalia-greeter = {
        enable = true;
        settings = {
          session.default = "niri";
          user.default = host.user;
        };
      };

      security.polkit = {
        enable = true;
        enablePkexecWrapper = true;
        extraConfig = let
          program = "${config.programs.noctalia-greeter.package}/bin/noctalia-greeter-apply-appearance";
        in ''
          polkit.addRule(function(action, subject) {
            if (
              action.id == "org.freedesktop.policykit.exec" &&
              action.lookup("program") == "${program}" &&
              subject.user == "${host.user}" &&
              subject.local &&
              subject.active
            ) {
              return polkit.Result.YES;
            }
          });
        '';
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
            background-effect = [{blur = false;}];
          };
        }
      ];

      environment.systemPackages = [
        pkgs.ddcutil
        package
      ];

      sumi = {
        configFile = {
          "noctalia/config.toml" = {
            watch = "theme";
            value = ctx:
              lib.toml.toTOML (settings {
                theme = ctx.value;
                lockscreen = cfg.lockscreen;
              });
          };

          "noctalia/palettes/Nook.json" = {
            watch = "theme";
            value = ctx: let
              palette = colors ctx.value;
            in
              builtins.toJSON {
                dark = palette;
                light = palette;
              };
          };
        };
        hook.noctalia = {
          watch = "theme";
          command = ctx: let
            wallpaper = lib.escapeShellArg (toString ctx.value.image);
          in ''
            ${noctalia} msg config-reload || true
            ${noctalia} msg wallpaper-set ${wallpaper} || true
          '';
        };
      };
    };
  };
}
