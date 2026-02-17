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
      pavucontrol
      kitty
      bluetui
      coreutils
    ];
  in {
    environment.systemPackages = [pkgs.quickshell];

    sumi.file = {
      "quickshell/shell.qml" = {
        dependsOn = ["theme"];
        render = ctx: let
          theme = ctx.values.theme;
          fonts = theme.fonts;
        in
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
              }
            }
          '';
      };

      "quickshell/components".source = config.lib.sumi.mkOutOfStoreSymlink "${quickshellRoot}/components";
    };

    sumi.program.quickshell.reload = "${pkgs.systemd}/bin/systemctl --user restart quickshell.service";

    systemd.user.services.quickshell = {
      description = "Quickshell";
      partOf = ["hyprland-session.target"];
      after = ["hyprland-session.target"];
      wantedBy = ["hyprland-session.target"];

      serviceConfig = {
        ExecStart = "${pkgs.quickshell}/bin/qs -n";
        Restart = "on-failure";
        RestartSec = 1;
      };

      path = runtimePackages;
    };
  };
}
