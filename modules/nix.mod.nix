{
  config,
  inputs,
  lib,
  ...
}: let
  flakeConfig = config;
  self = inputs.self;
  shortRev = self.shortRev or self.dirtyShortRev or "unknown";
in {
  mod.common.nix = {config, ...}: {
    options.nixpkgs.allowedUnfreePackages = lib.mkOption {
      type = lib.types.listOf lib.types.package;
      default = [];
    };

    config = {
      nix.settings = flakeConfig.nixConfig;
      nixpkgs.config.allowUnfreePredicate = package:
        builtins.elem
        (lib.getName package)
        (config.nixpkgs.allowedUnfreePackages |> map lib.getName);
    };
  };

  mod.nixos.nix = {
    system.configurationRevision = shortRev;
    system.nixos.label = "${shortRev}-${self.lastModifiedDate}";

    nix.gc = {
      automatic = true;
      dates = "daily";
      options = "--delete-older-than +5";
    };
  };

  mod.nixos.nuke-default-packages = {
    environment.defaultPackages = [];
    environment.stub-ld.enable = false;
  };
}
