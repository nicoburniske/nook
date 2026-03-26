{...}: {
  flake.modules.nixos.quickshell = {
    config,
    pkgs,
    ...
  }: let
    configHome = config.lib.sumi.paths.config;
    flakeRoot = config.lib.sumi.paths.flakeRootOrErr;
    quickshellRoot = "${flakeRoot}/modules/quickshell";
    runtimePackages = with pkgs; [
      bash
      pipewire
      wireplumber
      hyprland
      pavucontrol
      kitty
      bluetui
      coreutils
    ];
  in {
    environment.systemPackages = [pkgs.quickshell];

    sumi.configFile = {
      "quickshell/shell.qml" = {
        watch = ["theme"];
        value = ctx: let
          theme = ctx.values.theme;
          fonts = theme.fonts;
        in
          with theme.colors.withHashtag; ''
            import Quickshell
            import "file:${configHome}/quickshell/components"

            Scope {
              id: root

              property string desktopEnv: (
                Quickshell.env("XDG_CURRENT_DESKTOP")
                || Quickshell.env("XDG_SESSION_DESKTOP")
                || ""
              ).toLowerCase()

              property bool hasHyprSignature: Quickshell.env("HYPRLAND_INSTANCE_SIGNATURE") !== null
                && Quickshell.env("HYPRLAND_INSTANCE_SIGNATURE") !== ""

              property bool isHyprland: root.desktopEnv.indexOf("hyprland") !== -1
                || root.hasHyprSignature

              property var theme: ({
                base00: "${base00}",
                base01: "${base01}",
                base03: "${base03}",
                base05: "${base05}",
                base0C: "${base0C}",
                base08: "${base08}",

                monospaceFont: ${builtins.toJSON fonts.monospace.name},
                emojiFont: ${builtins.toJSON fonts.emoji.name},
                fontSize: ${toString fonts.sizes.desktop},

                barHeight: 40,
                radius: 5,

                widgetBg: "${base01}",
                widgetBorder: "${base03}",
                fg: "${base05}",
                danger: "${base08}"
              })

              Bar {
                theme: root.theme
                isHyprland: root.isHyprland
              }
            }
          '';
      };

      "quickshell/components".value = config.lib.sumi.mkOutOfStoreSymlink "${quickshellRoot}/components";
    };

    sumi.hook.quickshell = {
      watch = ["theme"];
      command = "${pkgs.systemd}/bin/systemctl --user restart quickshell.service";
    };

    systemd.user.services.quickshell = {
      description = "Quickshell";
      partOf = ["compositor-session.target"];
      after = ["compositor-session.target"];
      wantedBy = ["compositor-session.target"];

      serviceConfig = {
        ExecStart = "${pkgs.quickshell}/bin/qs -n";
        Restart = "on-failure";
        RestartSec = 1;
      };

      path = runtimePackages;
    };
  };
}
