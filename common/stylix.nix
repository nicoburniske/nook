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
          image = ../assets/wallpapers/the-backwater.jpg;
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
            base02 = "efe9dd"; # bg-dim
            base03 = "9f9690"; # border
            base04 = "595959"; # fg-dim
            base05 = "000000"; # fg-main
            base06 = "193668"; # fg-alt
            base07 = "000000"; # fg-main (bright fallback)
            base08 = "a0132f"; # red-cooler
            base09 = "972500"; # red-warmer
            base0A = "6d5000"; # yellow
            base0B = "006300"; # green
            base0C = "005f5f"; # cyan-cooler
            base0D = "3546c2"; # blue-warmer
            base0E = "531ab6"; # magenta-cooler
            base0F = "894000"; # yellow-warmer
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
