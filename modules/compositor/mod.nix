{
  nixosModules.compositor = {lib, ...}: {
    options.compositor = {
      startupCommands = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [];
        description = "shell commands started by the active compositor";
      };
      niri = {
        workspaceOutput = lib.mkOption {
          type = lib.types.nullOr lib.types.str;
          default = null;
          description = "home output for named workspaces";
        };
        config = lib.mkOption {
          type = lib.types.listOf lib.types.attrs;
          default = [];
          description = "niri config KDL nodes";
        };
        themedConfig = lib.mkOption {
          type = lib.types.listOf (lib.types.functionTo lib.types.attrs);
          default = [];
          description = "niri config KDL nodes rendered with the active theme";
        };
        binds = lib.mkOption {
          type = lib.types.listOf lib.types.attrs;
          default = [];
          description = "niri keybind KDL nodes";
        };
      };
    };
  };
}
