{inputs, ...}: {
  flake.modules.nixos.noctalia = {
    config,
    lib,
    pkgs,
    ...
  }: let
    cfg = config.programs.noctalia-shell;
    patches = [
      {
        file = "Commons/Style.qml";
        before = ''readonly property color capsuleBorderColor: Settings.data.bar.showOutline ? Color.mPrimary : "transparent"'';
        after = ''readonly property color capsuleBorderColor: Settings.data.bar.showOutline ? Color.mOutline : "transparent"'';
      }
      {
        file = "Modules/Bar/Widgets/Volume.qml";
        before = ''forceClose: displayMode === "alwaysHide"'';
        after = "forceClose: true";
      }
      {
        file = "Modules/Bar/Widgets/Brightness.qml";
        before = ''forceClose: displayMode === "alwaysHide"'';
        after = "forceClose: true";
      }
      {
        file = "Modules/MainScreen/Backgrounds/PanelBackground.qml";
        before = "strokeWidth: -1 // No stroke, fill only";
        after = "strokeWidth: effectiveBackgroundColor.a > 0 ? Style.borderM : -1\n  strokeColor: Color.mOutline";
      }
      {
        file = "Services/Theming/ColorSchemeService.qml";
        before = ''ToastService.showNotice(label, description, "dark-mode");'';
        after = "";
      }
    ];
    mkPatch = patch: ''
      substituteInPlace ${lib.escapeShellArg patch.file} \
        --replace-fail ${lib.escapeShellArg patch.before} \
                       ${lib.escapeShellArg patch.after}
    '';
    package = inputs.noctalia.packages.${pkgs.stdenv.hostPlatform.system}.default.overrideAttrs (old: {
      postPatch =
        (old.postPatch or "")
        + lib.concatMapStrings mkPatch patches;
    });
    settings = import ./_settings.nix;
    colors = import ./_colors.nix;
  in {
    options.programs.noctalia-shell = {
      enable = lib.mkEnableOption "Noctalia shell";
    };

    config = lib.mkIf cfg.enable {
      compositor.shell.command = lib.mkDefault (lib.getExe package);

      environment.systemPackages = [
        package
      ];

      sumi.configFile = {
        "noctalia/settings.json" = {
          watch = ["theme"];
          value = ctx: "${builtins.toJSON (settings ctx.values.theme)}\n";
        };

        "noctalia/colors.json" = {
          watch = ["theme"];
          value = ctx: "${builtins.toJSON (colors ctx.values.theme)}\n";
        };
      };

      sumi.cacheFile."noctalia/wallpapers.json" = {
        watch = ["theme"];
        value = ctx: let
          wallpaperPath = toString ctx.values.theme.image;
        in
          builtins.toJSON {
            defaultWallpaper = wallpaperPath;
            wallpapers = {};
          }
          + "\n";
      };
    };
  };
}
