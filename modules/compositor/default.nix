{...}: {
  flake.modules.nixos.compositor = {lib, ...}: {
    options.compositor.startupCommands = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [];
      description = "Shell commands started by the active compositor.";
    };
  };
}
