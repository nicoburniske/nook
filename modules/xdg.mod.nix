{
  commonModules.xdg = {
    config,
    lib,
    ...
  }: let
    cfg = config.sumi.xdg;
    toDesktopList = applications: lib.concatStringsSep ";" applications + ";";
  in {
    options.sumi.xdg.mime.defaultApplications = lib.mkOption {
      type = lib.types.attrsOf (lib.types.listOf lib.types.str);
      default = {};
      description = "XDG default applications written to mimeapps.list";
    };

    config = lib.mkIf (cfg.mime.defaultApplications != {}) {
      sumi.configFile."mimeapps.list".value = lib.generators.toINI {} {
        "Default Applications" = lib.mapAttrs (_: toDesktopList) cfg.mime.defaultApplications;
      };
    };
  };
}
