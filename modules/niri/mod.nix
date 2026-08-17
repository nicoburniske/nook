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
      })
    ];

    hardware.i2c.enable = true;
    programs.niri.enable = true;
  };

  homeModules.niri = {
    host,
    lib,
    osConfig,
    pkgs,
    ...
  }: let
    keybinds = import ./keybinds {
      inherit host lib pkgs;
    };
    configKdl = lib.kdl.toKDL (
      (import ./config.nix {config = osConfig;})
      ++ osConfig.compositor.niri.config
      ++ (import ./rules.nix)
      ++ [{binds = keybinds;}]
    );
    mkTheme = import ./theme.nix {inherit lib;};
  in {
    packages = with pkgs; [
      phinger-cursors
      playerctl
      wl-clipboard
      xwayland-satellite
    ];

    file.config = {
      "niri/config.kdl".value = ''
        include "theme.kdl"
        ${configKdl}
      '';

      "niri/theme.kdl" = {
        facet = "theme";
        value = {theme}: lib.kdl.toKDL (mkTheme theme.value);
      };
    };
  };
}
