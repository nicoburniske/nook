{pkgs, ...}: let
  berkeleyMono = import ./berkeley-mono.nix {inherit pkgs;};

  baseFonts = {
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
      terminal = 12;
      desktop = 10;
      popups = 10;
    };
  };
in {
  themes = [
    {
      stylix = {
        enable = true;
        base16Scheme = "${pkgs.base16-schemes}/share/themes/gruvbox-dark-hard.yaml";
        override = {slug = "gruvbox-dark";};
        polarity = "dark";
        image = ./wallpapers/dark-evangelion.png;
        fonts = baseFonts;
      };
    }

    {
      stylix = {
        enable = true;
        base16Scheme = "${pkgs.base16-schemes}/share/themes/gruvbox-light-hard.yaml";
        override = {slug = "gruvbox-light-hard";};
        polarity = "light";
        image = ./wallpapers/falling.jpg;
        fonts = baseFonts;
      };
    }

    {
      stylix = {
        enable = true;
        base16Scheme = "${pkgs.base16-schemes}/share/themes/catppuccin-mocha.yaml";
        override = {slug = "catppuccin-mocha";};
        polarity = "dark";
        image = ./wallpapers/frozen.png;
        fonts = baseFonts;
      };
    }

    {
      # https://github.com/protesilaos/modus-themes/blob/main/modus-operandi-tinted-theme.el
      stylix = {
        enable = true;
        base16Scheme = {
          scheme = "Modus Operandi Tinted";
          author = "Protesilaos Stavrou";
          base00 = "fbf7f0"; # bg-main - primary background
          base01 = "f1d5d0"; # bg-hl-line - pinkish highlight background
          base02 = "c2bcb5"; # bg-region - pinkish selection color
          base03 = "595959"; # fg-dim - lighter/dimmed text
          base04 = "585858"; # fg-mode-line-inactive - darkest text
          base05 = "000000"; # fg-main - primary text
          base06 = "193668"; # fg-alt - light forground
          base07 = "9f9690"; # border - lightest (for contrast in dark mode)
          base08 = "a60000"; # red - errors, deletion
          base09 = "894000"; # yellow-warmer - warnings, constants
          base0A = "6d5000"; # yellow - classes, search
          base0B = "006300"; # green - strings, success
          base0C = "00598b"; # cyan - support, info
          base0D = "0031a9"; # blue - functions, links
          base0E = "721045"; # magenta - keywords
          base0F = "972500"; # red-warmer - deprecated, special
        };
        override = {slug = "modus-operandi";};
        polarity = "light";
        image = ./wallpapers/light-porsche.png;
        fonts = baseFonts;
      };
    }
  ];
}
