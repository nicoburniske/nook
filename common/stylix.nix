{
  lib,
  pkgs,
  ...
}: let
  berkeleyMono = import ./berkeley-mono.nix {inherit pkgs;};

  baseConfig = {
    enable = true;

    # looks bad on mac without blur
    opacity =
      lib.optionalAttrs
      pkgs.stdenv.isLinux
      {
        terminal = 0.90;
      };

    fonts = {
      monospace = {
        package = berkeleyMono;
        name = "Berkeley Mono";
      };

      sansSerif = {
        package = berkeleyMono;
        name = "Berkeley Mono";
      };

      serif = {
        package = berkeleyMono;
        name = "Berkeley Mono";
      };

      emoji = {
        package = pkgs.nerd-fonts.symbols-only;
        name = "Symbols Nerd Font";
      };

      sizes = {
        applications = 12;
        terminal = 13;
        desktop = 12;
        popups = 12;
      };
    };
  };
in {
  themes = [
    {
      stylix =
        {
          base16Scheme = "${pkgs.base16-schemes}/share/themes/gruvbox-dark-hard.yaml";
          override = {slug = "gruvbox";};
          polarity = "dark";
          image = ../assets/wallpapers/dark-evangelion.png;
        }
        // baseConfig;
    }

    {
      stylix =
        {
          base16Scheme = "${pkgs.base16-schemes}/share/themes/everforest-dark-hard.yaml";
          override = {
            slug = "everforest";
            helix = "everforest_dark";
          };
          polarity = "dark";
          image = ../assets/wallpapers/light-mountains.jpg;
        }
        // baseConfig;
    }

    {
      stylix =
        {
          base16Scheme = {
            scheme = "space-age";
            base00 = "190f0f"; # dark_red0 - background
            base01 = "2c1617"; # dark_red2 - cursorline/lighter bg
            base02 = "442022"; # dark_red3 - selection/menu bg
            base03 = "704144"; # dark_red4 - comments/disabled
            base04 = "cebabf"; # white0 - foreground muted
            base05 = "cebabf"; # white0 - primary foreground
            base06 = "e97e8a"; # pink4 - bright foreground
            base07 = "e97e8a"; # pink4 - brightest
            base08 = "d2505f"; # pink1 - red/error
            base09 = "ff7550"; # orange0 - orange/constants
            base0A = "eb842b"; # orange1 - yellow/keywords
            base0B = "8ea84d"; # green0 - green/strings
            base0C = "65aba3"; # blue0 - cyan/info
            base0D = "65aba3"; # blue0 - blue/functions
            base0E = "ce8b9f"; # violet0 - magenta/specials
            base0F = "d95362"; # pink2 - brown/deprecated
          };
          override = {
            slug = "space-age";
            helix = "space-age";
          };
          polarity = "dark";
          image = ../assets/wallpapers/space.jpg;
        }
        // baseConfig;
    }

    {
      # https://github.com/protesilaos/modus-themes/blob/main/modus-operandi-tinted-theme.el
      stylix =
        {
          base16Scheme = {
            scheme = "Modus Operandi Tinted";
            author = "Protesilaos Stavrou";
            base00 = "fbf7f0"; # bg-main
            base01 = "f1d5d0"; # bg-hl-line
            base02 = "cab9b2"; # bg-mode-line-active
            base03 = "a59a94"; # border-mode-line-inactive
            base04 = "585858"; # fg-mode-line-inactive
            base05 = "000000"; # pure black
            base06 = "000000"; # pure black
            base07 = "000000"; # pure black
            base08 = "a60000"; # red
            base09 = "894000"; # yellow-warmer
            base0A = "6d5000"; # yellow
            base0B = "006300"; # green
            base0C = "00598b"; # cyan
            base0D = "0031a9"; # blue
            base0E = "721045"; # magenta
            base0F = "972500"; # red-warmer
          };
          override = {
            slug = "modus";
            helix = "modus";
          };
          polarity = "light";
          image = ../assets/wallpapers/light-painting.jpeg;
        }
        // baseConfig;
    }
  ];
}
