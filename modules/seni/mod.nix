{
  config,
  inputs,
  lib,
  ...
}: {
  inputs.seni = {
    url = "github:nicoburniske/seni";
    inputs = {
      nix-darwin.follows = "nix-darwin";
      nixpkgs.follows = "nixpkgs";
    };
  };

  flake.lib.seni.renderBase16Mustache = {
    theme,
    template,
  }: let
    bases = [
      "base00"
      "base01"
      "base02"
      "base03"
      "base04"
      "base05"
      "base06"
      "base07"
      "base08"
      "base09"
      "base0A"
      "base0B"
      "base0C"
      "base0D"
      "base0E"
      "base0F"
    ];
    colors = theme.colors;
    hexAt = index: builtins.substring index 2 colors.base01;
  in
    builtins.replaceStrings
    ((map (base: "{{${base}-hex}}") bases) ++ ["{{base01-dec-r}}" "{{base01-dec-g}}" "{{base01-dec-b}}"])
    ((map (base: colors.${base}) bases)
      ++ [
        (toString (lib.fromHexString (hexAt 0)))
        (toString (lib.fromHexString (hexAt 2)))
        (toString (lib.fromHexString (hexAt 4)))
      ])
    (
      if builtins.isPath template
      then builtins.readFile template
      else template
    );

  commonModules.seni = {
    config,
    host,
    lib,
    pkgs,
    ...
  }: let
    cfg = config.nook.seni;
    themes = import ./themes.nix {
      inherit pkgs lib;
      transparency = cfg.theme.transparency;
    };
  in {
    options.nook.seni.theme = {
      default = lib.mkOption {
        type = lib.types.str;
        default = "gruvbox";
        description = "default selected theme";
      };
      transparency = lib.mkOption {
        type = lib.types.submodule {
          options = {
            light = lib.mkOption {
              type = lib.types.float;
              default = 0.90;
              description = "opacity for light themes";
            };

            dark = lib.mkOption {
              type = lib.types.float;
              default = 0.90;
              description = "opacity for dark themes";
            };

            darkOnLight = lib.mkOption {
              type = lib.types.float;
              default = 0.93;
              description = "opacity for dark themes with light backgrounds";
            };
          };
        };
        default = {};
      };
    };
    config = {
      assertions = [
        {
          assertion =
            builtins.attrValues cfg.theme.transparency
            |> lib.all (value: value >= 0.0 && value <= 1.0);
          message = "nook.seni.theme.transparency values must be between 0.0 and 1.0.";
        }
      ];
      seni = {
        existingFileStrategy = "clobber";
        specialArgs = {inherit host;};
        users.${host.user} = {
          facet.theme = {
            default = cfg.theme.default;
            variants = themes;
          };

          effect.wallpaper = lib.mkIf pkgs.stdenv.hostPlatform.isDarwin {
            on = ["theme"];
            exec = {theme}: [
              (pkgs.writeShellScript "seni-darwin-wallpaper" ''
                set -eu

                store="$HOME/Library/Application Support/com.apple.wallpaper/Store/Index.plist"

                if ! /usr/bin/plutil -extract AllSpacesAndDisplays raw -expect dictionary "$store" >/dev/null 2>&1; then
                  system_default="$(/usr/bin/plutil -extract SystemDefault xml1 -o - "$store")"
                  /usr/bin/plutil -replace AllSpacesAndDisplays -xml "$system_default" "$store"
                  /usr/bin/plutil -replace Spaces -json '{}' "$store"
                  /usr/bin/plutil -replace Displays -json '{}' "$store"
                fi

                configuration="$(
                    /usr/bin/plutil -create binary1 - |
                    /usr/bin/plutil -insert type -string imageFile -o - - |
                    /usr/bin/plutil -insert url -dictionary -o - - |
                    /usr/bin/plutil -insert url.relative -string "file://$1" -o - - |
                    /usr/bin/base64 -b 0
                )"

                /usr/bin/plutil -replace AllSpacesAndDisplays.Desktop.Content.Choices.0.Configuration -data "$configuration" "$store"

                /usr/bin/killall WallpaperAgent >/dev/null 2>&1 || true
              '')
              (toString theme.value.image)
            ];
          };
        };
      };
    };
  };

  homeModules.seni.imports = [config.homeModules.xdg];

  nixosModules.seni = inputs.seni.nixosModules.default;
  darwinModules.seni = inputs.seni.darwinModules.default;
}
