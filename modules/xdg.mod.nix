{
  homeModules.xdg = {
    config,
    lib,
    ...
  }: {
    options.xdg.mime.defaultApplications = lib.mkOption {
      type = lib.types.attrsOf (lib.types.listOf lib.types.str);
      default = {};
      description = "XDG default applications written to mimeapps.list";
    };

    config = lib.mkIf (config.xdg.mime.defaultApplications != {}) {
      file.config."mimeapps.list".value = lib.generators.toINI {} {
        "Default Applications" =
          lib.mapAttrs
          (_: applications: lib.concatStringsSep ";" applications + ";")
          config.xdg.mime.defaultApplications;
      };
    };
  };
}
