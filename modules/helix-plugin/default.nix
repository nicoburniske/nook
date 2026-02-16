{inputs, ...}: let
  mkHelixPluginModule = {
    config,
    pkgs,
    ...
  }: let
    tomlFormat = pkgs.formats.toml {};

    helixSteelPackage =
      (inputs.helix-steel.packages.${pkgs.stdenv.hostPlatform.system}.default.override {
        includeGrammarIf = grammar: grammar.name != "go-format-string";
      }).overrideAttrs
      (prevAttrs: {
        cargoBuildFeatures = (prevAttrs.cargoBuildFeatures or []) ++ ["steel"];
      });

    hxPlugin = pkgs.writeShellScriptBin "hx-plugin" ''
      set -eu

      export HELIX_STEEL_CONFIG="${config.lib.sumi.paths.config}/helix-plugin/plugins"

      exec "${helixSteelPackage}/bin/hx" \
        -c "${config.lib.sumi.paths.config}/helix-plugin/config.toml" \
        "$@"
    '';
  in {
    environment.systemPackages = [hxPlugin];

    sumi.file = {
      "helix-plugin/config.toml" = {
        dependsOn = ["theme"];
        render = ctx: let
          theme = ctx.values.theme;
        in
          tomlFormat.generate "sumi-helix-plugin-config-${ctx.selection.theme}.toml" {
            theme = theme.meta.helix or ctx.selection.theme;

            editor = {
              line-number = "relative";
              cursorline = true;
              color-modes = true;
              true-color = true;
            };
          };
      };

      "helix-plugin/plugins".source = config.lib.sumi.mkOutOfStoreSymlink "${config.lib.sumi.paths.flakeRootOrErr}/modules/helix-plugin/plugins";
    };

    sumi.program.helixPlugin.reload =
      if pkgs.stdenv.isDarwin
      then "/usr/bin/pkill -USR1 hx || true"
      else "${pkgs.procps}/bin/pkill -USR1 hx || true";
  };
in {
  flake.modules.nixos.helixPlugin = mkHelixPluginModule;
  flake.modules.darwin.helixPlugin = mkHelixPluginModule;
}
