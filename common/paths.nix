{config, lib, ...}: {
  options.nook.paths = {
    flakeRoot = lib.mkOption {
      type = lib.types.str;
      default = "${config.home.homeDirectory}/nook";
      description = "Absolute path to local flake checkout.";
    };
  };
}
