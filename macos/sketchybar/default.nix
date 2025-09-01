{
  config,
  lib,
  pkgs,
  ...
}: let
  sbar-lua = pkgs.callPackage ./sbar-lua.nix {};
in {
  home.packages = with pkgs; [
    sketchybar
    lua5_4
    lua54Packages.lua-cjson
  ];

  xdg.configFile = {
    "sketchybar" = {
      source = lib.cleanSourceWith {
        src = lib.cleanSource ./config/.;
      };
      recursive = true;
    };

    "sketchybar/config.json" = let
      formatColor = color: "0xFF${color}";
    in {
      text = builtins.toJSON {
        theme = {
          bar = formatColor config.lib.stylix.colors.base00;
          bar_border = formatColor config.lib.stylix.colors.base00;
          icon = formatColor config.lib.stylix.colors.base05;
          label = formatColor config.lib.stylix.colors.base05;
          highlight = formatColor config.lib.stylix.colors.base03;
          background = formatColor config.lib.stylix.colors.base01;
          background_border = formatColor config.lib.stylix.colors.base02;
          popup_background = formatColor config.lib.stylix.colors.base01;
          popup_border = formatColor config.lib.stylix.colors.base02;
          transparent = "0x00000000";
          red = formatColor config.lib.stylix.colors.base08;
          polarity = config.stylix.polarity;
          is_dark = config.stylix.polarity == "dark";
          name = config.stylix.base16Scheme.scheme or config.stylix.base16Scheme.name or "Unknown";
        };
        font = config.stylix.fonts.monospace.name;
        icon_font = "JetBrainsMono Nerd Font";
        paddings = 4;
        icon_width = 36;
        flake_root = "${config.home.homeDirectory}/env";
      };
    };

    "sketchybar/sketchybarrc" = {
      executable = true;
      text = ''
        #!${pkgs.lua5_4}/bin/lua

        package.cpath = package.cpath .. ";${sbar-lua}/lib/lua/5.4/?.so;${pkgs.lua54Packages.lua-cjson}/lib/lua/5.4/?.so"
        package.path = package.path .. ";${config.home.homeDirectory}/.config/sketchybar/?.lua"

        require("init")
      '';
    };
  };

  home.shellAliases = {
    sketchy-restart = "launchctl unload ~/Library/LaunchAgents/org.nixos.sketchybar.plist 2>/dev/null && launchctl load -w ~/Library/LaunchAgents/org.nixos.sketchybar.plist 2>/dev/null";
  };
}
