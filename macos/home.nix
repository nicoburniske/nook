{ config, pkgs, lib, ... }: 
let
  themeDefinitions = import ../common/stylix.nix {inherit pkgs lib;};
  
  wait4Path = {command, ...} @ args:
    args
    // {
      ProgramArguments = [
        "/run/current-system/sw/bin/sh"
        "-c"
        "/bin/wait4path /nix/store && exec ${command}"
      ];
    };

  macosTheme = ''
    WALLPAPER="${toString config.stylix.image}"
    POLARITY="${config.stylix.polarity}"

    /usr/bin/osascript -e "tell application \"System Events\" to tell every desktop to set picture to POSIX file \"$WALLPAPER\""

    if [ "$POLARITY" = "light" ]; then
      /usr/bin/osascript -e 'tell application "System Events" to tell appearance preferences to set dark mode to false'
    else
      /usr/bin/osascript -e 'tell application "System Events" to tell appearance preferences to set dark mode to true'
    fi
  '';

  jankybordersCmd = let
    settings = [
      "active_color=0xff${config.lib.stylix.colors.base08}"
      "inactive_color=0xff${config.lib.stylix.colors.base01}"
      "width=6.0"
      "style=round"
      "hidpi=on"
    ];
  in "${pkgs.jankyborders}/bin/borders ${lib.concatStringsSep " " settings}";
in {
  imports = [
    ../common/packages.nix

    ../common/git.nix
    ../common/helix.nix
    ../common/starship.nix
    ../common/zellij.nix
    ../common/yazi.nix
    ../common/zsh.nix
    ../common/fzf.nix
    ../common/zoxide.nix
    ../common/ghostty.nix
    ../common/opencode.nix
    ../common/lazygit.nix
    ../common/cargo.nix
    ../common/scooter.nix
    ../common/comically.nix
    ../common/theme-switcher.nix
    
    ./sketchybar
    ./hammerspoon
  ];

  home.username = "nicoburniske";
  home.homeDirectory = "/Users/nicoburniske";
  home.stateVersion = "24.05";

  programs.home-manager.enable = true;

  fonts.fontconfig.enable = true;

  stylix = lib.mkDefault (builtins.head themeDefinitions.themes).stylix;

  home.packages = with pkgs; [
    nowplaying-cli
    yq-go

    # envoy 
    flutter335
    rust-bindgen
    cocoapods
  ];

  launchd.agents."set-macos-theme" = {
    enable = true;
    config = wait4Path {
      command = toString (pkgs.writeShellScript "set-macos-theme" macosTheme);
      serviceConfig = {
        RunAtLoad = true;
        StandardOutPath = "/tmp/theme.log";
        StandardErrorPath = "/tmp/theme.err.log";
      };
    };
  };

  launchd.agents.jankyborders = {
    enable = true;
    config = wait4Path {
      command = jankybordersCmd;
      serviceConfig = {
        KeepAlive = true;
        RunAtLoad = true;
        StandardOutPath = "/tmp/jankyborders.log";
        StandardErrorPath = "/tmp/jankyborders.err.log";
        EnvironmentVariables = {
          PATH = lib.makeBinPath [pkgs.jankyborders];
        };
      };
    };
  };

  launchd.agents.sketchybar = {
    enable = true;
    config = wait4Path {
      command = "${pkgs.sketchybar}/bin/sketchybar --config ${config.home.homeDirectory}/.config/sketchybar/sketchybarrc";
      Label = "org.nixos.sketchybar";
      EnvironmentVariables = {
        CONFIG_DIR = "${config.home.homeDirectory}/.config/sketchybar";
        PATH = "${pkgs.sketchybar}/bin:${pkgs.lua5_4}/bin:/nix/var/nix/profiles/default/bin:/usr/bin:/bin";
      };
      KeepAlive = true;
      RunAtLoad = true;
      StandardErrorPath = "/tmp/sketchybar.err.log";
      StandardOutPath = "/tmp/sketchybar.out.log";
    };
  };

  home.activation.applyTheme = lib.hm.dag.entryAfter ["linkGeneration"] ''
    ${macosTheme}
    echo "reloading sketchybar"
    ${pkgs.sketchybar}/bin/sketchybar --reload || true
    echo "reloading jankyborders"
    ${jankybordersCmd} || true
  '';

  specialisation = builtins.listToAttrs (
    map (theme: {
      name = theme.stylix.override.slug;
      value = {
        configuration = {
          stylix = lib.mkForce theme.stylix;
        };
      };
    })
    themeDefinitions.themes
  );
}
