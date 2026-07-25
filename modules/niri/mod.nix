{inputs, ...}: {
  inputs = {
    niri = {
      url = "github:dividebysandwich/niri/main";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    smithay = {
      url = "github:dividebysandwich/smithay/master";
      flake = false;
    };
  };
  nixosModules.niri = {
    config,
    lib,
    pkgs,
    ...
  }: let
    keybinds = import ./keybinds {
      inherit config inputs lib pkgs;
    };

    baseConfig = import ./config.nix {
      inherit config;
    };
    mkTheme = import ./theme.nix {inherit lib;};
    configKdl = lib.kdl.toKDL (
      baseConfig
      ++ config.compositor.niri.config
      ++ (import ./rules.nix)
      ++ [
        {
          binds = keybinds;
        }
      ]
    );
  in {
    sumi.configFile = {
      "niri/config.kdl".value = ''
        include "theme.kdl"
        ${configKdl}
      '';

      "niri/theme.kdl" = {
        watch = "theme";
        value = ctx: lib.kdl.toKDL (mkTheme ctx.value);
      };
    };

    nixpkgs.overlays = [
      (final: prev: {
        niri = inputs.niri.packages.${final.stdenv.hostPlatform.system}.niri.overrideAttrs (old: {
          postPatch =
            (old.postPatch or "")
            + ''
              ln -s ${inputs.smithay} ../smithay
            '';

          patches =
            (old.patches or [])
            ++ [
              ./patches/workspace-switch-animate-property.patch
              ./patches/hdr-sdr-controls.patch
            ];
        });

        xwayland-satellite = prev.xwayland-satellite.overrideAttrs (old: {
          patches = (old.patches or []) ++ [./patches/steam-osk-toplevel.patch];
        });
      })
    ];

    hardware.i2c.enable = true;

    programs.niri.enable = true;

    environment.systemPackages = with pkgs; [
      phinger-cursors
      playerctl
      wl-clipboard
      xwayland-satellite
    ];
  };
}
