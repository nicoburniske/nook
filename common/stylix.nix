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
      terminal = 13;
      desktop = 12;
      popups = 12;
    };
  };
in {
  themes = [
    {
      stylix = {
        enable = true;
        base16Scheme = "${pkgs.base16-schemes}/share/themes/gruvbox-dark-hard.yaml";
        override = {slug = "gruvbox";};
        polarity = "dark";
        image = ../assets/wallpapers/dark-evangelion.png;
        fonts = baseFonts;
      };
    }

    {
      stylix = {
        enable = true;
        base16Scheme = "${pkgs.base16-schemes}/share/themes/everforest-dark-hard.yaml";
        override = {
          slug = "everforest";
          helix = "everforest_dark";
        };
        polarity = "dark";
        image = ../assets/wallpapers/light-mountains.jpg;
        fonts = baseFonts;
      };
    }

    # {
    #   stylix = {
    #     enable = true;
    #     base16Scheme = "${pkgs.base16-schemes}/share/themes/catppuccin-mocha.yaml";
    #     override = {slug = "catppuccin-mocha";};
    #     polarity = "dark";
    #     image = ../assets/wallpapers/frozen.png;
    #     fonts = baseFonts;
    #   };
    # }

    {
      # https://github.com/protesilaos/modus-themes/blob/main/modus-operandi-tinted-theme.el
      stylix = {
        enable = true;
        base16Scheme = {
          scheme = "Modus Operandi Tinted";
          author = "Protesilaos Stavrou";
          base00 = "fbf7f0"; # bg-main
          base01 = "f1d5d0"; # bg-hl-line
          base02 = "f1c8b5"; # bg-clay
          base03 = "80601f"; # gold
          base04 = "63192a"; # fg-clay
          base05 = "000000"; # fg-main
          base06 = "193668"; # fg-alt
          base07 = "9f9690"; # border
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
          slug = "modus-operandi";
          helix = "modus_operandi_tinted";
        };
        polarity = "light";
        image = ../assets/wallpapers/light-porsche.png;
        fonts = baseFonts;
      };
    }
  ];
}
