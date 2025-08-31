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
    ./flake-root.nix
    
    # Common configurations
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
    ../common/packages.nix
    ../common/theme-switcher.nix
    
    # macOS-specific modules
    ./sketchybar
    ./hammerspoon
  ];

  home.username = "nico";
  home.homeDirectory = "/Users/nico";
  home.stateVersion = "24.05";

  programs.home-manager.enable = true;

  fonts.fontconfig.enable = true;

  stylix = lib.mkDefault (builtins.head themeDefinitions.themes).stylix;

  # macOS-specific packages
  home.packages = with pkgs; [
    nowplaying-cli
    yq-go
    gh
    just
    flutter335
    rust-bindgen
    cocoapods
    
    # Yazi file picker helper for Helix
    (writeShellScriptBin "yz-fp" ''
      #!/usr/bin/env bash
      zellij action toggle-floating-panes
      zellij action write 27 # send escape key
      for selected_file in "$@"
      do
        zellij action write-chars ":open $selected_file"
        zellij action write 13 # send enter key
      done
      zellij action toggle-floating-panes
      zellij action close-pane
    '')
    
    # Zellij session switcher
    (writeShellScriptBin "zj" ''
      #!/usr/bin/env bash
      sessions=$(zellij list-sessions -n 2>/dev/null | grep -v "EXITED")

      if [ -z "$sessions" ]; then
        echo "No active sessions"
        exit 1
      fi

      selected=$(echo "$sessions" | fzf \
        --header="Switch Session" \
        --height=100% \
        --layout=reverse)

      if [ -n "$selected" ]; then
        session_name=$(echo "$selected" | awk '{print $1}')
        zellij attach "$session_name"
      fi
    '')
  ];

  launchd.agents."set-macos-theme" = wait4Path {
    command = toString (pkgs.writeShellScript "set-macos-theme" macosTheme);
    serviceConfig = {
      RunAtLoad = true;
      StandardOutPath = "/tmp/theme.log";
      StandardErrorPath = "/tmp/theme.err.log";
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

  # Theme specialisations
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