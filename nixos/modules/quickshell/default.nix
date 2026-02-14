{
  config,
  pkgs,
  ...
}: let
  configHome = config.lib.velum.paths.config;
  flakeRoot = config.lib.velum.paths.flakeRootOrErr;
  quickshellRoot = "${flakeRoot}/nixos/modules/quickshell";
in {
  environment.systemPackages = [pkgs.quickshell];

  velum.programs.quickshell = {
    "quickshell/shell.qml".render = theme:
      with theme.colors.withHashtag; ''
        import Quickshell
        import "file:${configHome}/quickshell/components"

        Scope {
          id: root

          property var theme: ({
            base00: "${base00}",
            base01: "${base01}",
            base03: "${base03}",
            base05: "${base05}",
            base0C: "${base0C}",
            base08: "${base08}",

            monospaceFont: ${builtins.toJSON theme.fonts.monospace.name},
            emojiFont: ${builtins.toJSON theme.fonts.emoji.name},
            fontSize: ${toString theme.fonts.sizes.desktop},

            barHeight: 40,
            radius: 5,

            widgetBg: "${base01}",
            widgetBorder: "${base03}",
            fg: "${base05}",
            danger: "${base08}"
          })

          Bar {
            theme: root.theme
          }
        }
      '';

    "quickshell/components".source = config.lib.velum.mkOutOfStoreSymlink "${quickshellRoot}/components";

    reload = "${pkgs.systemd}/bin/systemctl --user restart quickshell.service || true";
  };

  systemd.user.services.quickshell = {
    description = "Quickshell";
    partOf = ["hyprland-session.target"];
    after = ["hyprland-session.target"];
    wantedBy = ["hyprland-session.target"];

    unitConfig = {
      ConditionEnvironment = "WAYLAND_DISPLAY";
    };

    serviceConfig = {
      ExecStart = "${pkgs.quickshell}/bin/qs -n";
      Restart = "on-failure";
      RestartSec = 1;
    };
  };
}
