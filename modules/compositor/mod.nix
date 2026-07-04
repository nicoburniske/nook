{
  nixosModules.compositor = {lib, ...}: {
    options.compositor = {
      startupCommands = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [];
        description = "shell commands started by the active compositor";
      };

      niri.config = lib.mkOption {
        type = lib.types.listOf lib.types.attrs;
        default = [];
        description = "niri config KDL nodes";
      };
    };
  };
}
