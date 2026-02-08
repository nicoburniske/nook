{
  config,
  pkgs,
  lib,
  ...
}: let
  themeDefinitions = import ../common/stylix.nix {inherit pkgs lib;};

  wait4Path = command: [
    "/run/current-system/sw/bin/sh"
    "-c"
    "/bin/wait4path /nix/store && exec ${command}"
  ];

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
in {
  imports = [
    ../common/packages.nix

    ../common/git.nix
    ../common/paths.nix
    ../common/helix/default.nix
    ../common/oh-my-posh.nix
    ../common/yazi/default.nix
    ../common/zsh.nix
    ../common/fzf.nix
    ../common/zoxide.nix
    ../common/ghostty.nix
    ../common/kitty.nix
    ../common/opencode.nix
    ../common/lazygit.nix
    ../common/cargo.nix
    ../common/comically.nix
    ../common/theme-switcher.nix
    ../common/direnv.nix

    ./sketchybar
    ./hammerspoon
  ];

  home.username = "nicoburniske";
  home.homeDirectory = "/Users/nicoburniske";
  home.stateVersion = "24.05";

  programs.home-manager.enable = true;
  xdg.enable = true;

  fonts.fontconfig.enable = true;

  stylix = lib.mkDefault (builtins.head themeDefinitions.themes).stylix;

  home.packages = with pkgs; [
    nowplaying-cli
    yq-go
  ];

  launchd.agents = {
    "set-macos-theme" = {
      enable = true;
      config = {
        ProgramArguments = wait4Path (toString (pkgs.writeShellScript "set-macos-theme" macosTheme));
        RunAtLoad = true;
        StandardOutPath = "/tmp/theme.log";
        StandardErrorPath = "/tmp/theme.err.log";
      };
    };

    sketchybar = {
      enable = true;
      config = {
        ProgramArguments = wait4Path "${pkgs.sketchybar}/bin/sketchybar --config ${config.home.homeDirectory}/.config/sketchybar/sketchybarrc";
        Label = "org.nixos.sketchybar";
        EnvironmentVariables = {
          PATH = "$PATH:/bin:/usr/bin";
        };
        KeepAlive = true;
        RunAtLoad = true;
        StandardErrorPath = "/tmp/sketchybar.err.log";
        StandardOutPath = "/tmp/sketchybar.out.log";
      };
    };
  };

  home.activation.applyTheme = lib.hm.dag.entryAfter ["linkGeneration"] ''
    ${macosTheme}
    echo "reloading sketchybar"
    ${pkgs.sketchybar}/bin/sketchybar --reload || true
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
