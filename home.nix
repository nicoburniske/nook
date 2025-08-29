{ config, pkgs, lib, ... }:

let
  themeDefinitions = import ./stylix.nix {inherit pkgs lib;};
in {
  # Home Manager needs a bit of information about you and the paths it should manage.
  home.username = "nico";
  home.homeDirectory = "/home/nico";

  # This value determines the Home Manager release that your configuration is
  # compatible with. This helps avoid breakage when a new Home Manager release
  # introduces backwards incompatible changes.
  home.stateVersion = "24.05";

  # Let Home Manager install and manage itself.
  programs.home-manager.enable = true;

  # Enable dconf for GNOME settings
  dconf.enable = true;

  # Stylix theming - apply default theme (Gruvbox Dark Hard)
  stylix = lib.mkMerge [
    (lib.mkDefault (builtins.head themeDefinitions.themes).stylix)
  ];

  # Zoxide shell integration (fixing the z command issue)
  programs.zoxide = {
    enable = true;
    enableBashIntegration = true;
  };

  # Basic git configuration (simplified from macOS config)
  programs.git = {
    enable = true;
    userName = "Nico Burniske";
    userEmail = "nicoburniske@gmail.com";

    signing = {
      key = "~/.ssh/id_ed25519.pub";
      signByDefault = true;
    };

    aliases = {
      ca = "commit --amend --no-edit";
    };

    extraConfig = {
      gpg.format = "ssh";
      commit.gpgsign = true;
      push.autoSetupRemote = true;
      core = {
        pager = "delta";
        editor = "hx";
      };
      delta = {
        navigate = true;
        side-by-side = true;
        line-numbers = true;
        hyperlinks = true;
        features = "stylix";

        "stylix" = with config.lib.stylix.colors; {
          "${
            if config.stylix.polarity == "dark"
            then "dark"
            else "light"
          }" = true;

          file-style = "#${base05} bold";
          file-decoration-style = "#${base0A} ul";
          file-added-label = "[+]";
          file-copied-label = "[==]";
          file-modified-label = "[*]";
          file-removed-label = "[-]";
          file-renamed-label = "[->]";

          hunk-header-decoration-style = "#${base0D} box ul";
          hunk-header-file-style = "#${base0C}";
          hunk-header-line-number-style = "#${base0A}";
          hunk-header-style = "file line-number syntax";

          line-numbers-left-format = "{nm:>3}┊";
          line-numbers-right-format = "{np:>3}┊";
          line-numbers-left-style = "#${base03}";
          line-numbers-right-style = "#${base03}";
          line-numbers-minus-style = "#${base08} bold";
          line-numbers-plus-style = "#${base0B} bold";
          line-numbers-zero-style = "#${base04}";

          minus-style = "syntax #${base01}";
          minus-emph-style =
            "syntax "
            + (
              if config.stylix.polarity == "dark"
              then "#332222"
              else "#fff5f5"
            );
          plus-style = "syntax #${base01}";
          plus-emph-style =
            "syntax "
            + (
              if config.stylix.polarity == "dark"
              then "#223322"
              else "#f5fff5"
            );

          zero-style = "syntax";
          whitespace-error-style = "#${base08} reverse";

          commit-decoration-style = "#${base0A} box";
          commit-style = "#${base05} bold";

          blame-code-style = "syntax";
          blame-format = "{author:<18} ({commit:>7}) ┊{timestamp:^16}┊ ";
          blame-palette = "#${base00} #${base01} #${base02} #${base03}";
        };
      };
    };
  };

  # Basic helix configuration (simplified from macOS config)
  programs.helix = {
    enable = true;

    settings = {
      editor = {
        bufferline = "always";
        cursorline = true;
        color-modes = true;
        end-of-line-diagnostics = "hint";
        popup-border = "all";

        cursor-shape = {
          insert = "bar";
        };

        file-picker = {
          hidden = false;
        };

        lsp = {
          display-messages = true;
          goto-reference-include-declaration = false;
        };

        inline-diagnostics = {
          cursor-line = "info";
        };
      };

      keys.normal = {
        X = "extend_line_above";

        space = {
          q = ":quit";
          w = ":write";
        };
      };

      keys.select = {
        X = "extend_line_above";
      };
    };

    languages = {
      language = [
        {
          name = "rust";
          language-servers = ["rust-analyzer"];
        }
        {
          name = "markdown";
          language-servers = ["marksman"];
        }
        {
          name = "nix";
          language-servers = ["nil"];
        }
        {
          name = "dart";
          language-servers = ["dart"];
        }
      ];

      language-server = {
        rust-analyzer = {
          command = "rust-analyzer";
          config = {
            checkOnSave.enable = true;
            procMacro.enable = true;
          };
        };

        nil = {
          command = "nil";
        };

        dart = {
          command = "dart";
        };
      };
    };
  };

  # Hyprland configuration with home-manager
  programs.kitty.enable = true; # required for the default Hyprland config
  
  wayland.windowManager.hyprland = {
    enable = true;
    # Use packages from NixOS module to avoid version conflicts
    package = null;
    portalPackage = null;
    
    # Import systemd environment variables for proper service integration
    systemd.variables = ["--all"];
    
    # Basic configuration
    settings = {
      "$mod" = "SUPER";
      
      # Basic keybinds
      bind = [
        "$mod, Return, exec, kitty"
        "$mod, Q, killactive"
        "$mod, M, exit"
        "$mod, F, togglefloating"
        "$mod, R, exec, rofi -show drun"
        
        # Move focus
        "$mod, H, movefocus, l"
        "$mod, L, movefocus, r"
        "$mod, K, movefocus, u"
        "$mod, J, movefocus, d"
        
        # Workspaces
        "$mod, 1, workspace, 1"
        "$mod, 2, workspace, 2"
        "$mod, 3, workspace, 3"
        "$mod, 4, workspace, 4"
        "$mod, 5, workspace, 5"
        "$mod, 6, workspace, 6"
        "$mod, 7, workspace, 7"
        "$mod, 8, workspace, 8"
        "$mod, 9, workspace, 9"
        "$mod, 0, workspace, 10"
        
        # Move active window to a workspace
        "$mod SHIFT, 1, movetoworkspace, 1"
        "$mod SHIFT, 2, movetoworkspace, 2"
        "$mod SHIFT, 3, movetoworkspace, 3"
        "$mod SHIFT, 4, movetoworkspace, 4"
        "$mod SHIFT, 5, movetoworkspace, 5"
        "$mod SHIFT, 6, movetoworkspace, 6"
        "$mod SHIFT, 7, movetoworkspace, 7"
        "$mod SHIFT, 8, movetoworkspace, 8"
        "$mod SHIFT, 9, movetoworkspace, 9"
        "$mod SHIFT, 0, movetoworkspace, 10"
      ];
      
      # Mouse bindings
      bindm = [
        "$mod, mouse:272, movewindow"
        "$mod, mouse:273, resizewindow"
      ];
      
      # Basic input configuration
      input = {
        kb_layout = "us";
        follow_mouse = 1;
        touchpad = {
          natural_scroll = true;
        };
        sensitivity = 0;
      };
      
      # General settings
      general = {
        gaps_in = 5;
        gaps_out = 20;
        border_size = 2;
        layout = "dwindle";
        resize_on_border = true;
      };
      
      decoration = {
        rounding = 10;
        blur = {
          enabled = true;
          size = 3;
          passes = 1;
        };
        drop_shadow = true;
        shadow_range = 4;
        shadow_render_power = 3;
      };
      
      animations = {
        enabled = true;
        bezier = "myBezier, 0.05, 0.9, 0.1, 1.05";
        animation = [
          "windows, 1, 7, myBezier"
          "windowsOut, 1, 7, default, popin 80%"
          "border, 1, 10, default"
          "borderangle, 1, 8, default"
          "fade, 1, 7, default"
          "workspaces, 1, 6, default"
        ];
      };
      
      dwindle = {
        pseudotile = true;
        preserve_split = true;
      };
      
      misc = {
        force_default_wallpaper = -1;
      };
    };
  };

  # Basic packages that were in your macOS home config
  home.packages = with pkgs; [
    ripgrep
    fzf
    lazygit
    delta
    btop
    tokei
    just
    rust-analyzer
    nil
    marksman
  ];
}
