{inputs, ...}: let
  self = inputs.self;
  shortRev = self.shortRev or self.dirtyShortRev or "unknown";
in {
  flake.mod.common.nix = {
    nix.settings = (import "${self}/flake.nix").nixConfig;
  };

  flake.mod.nixos.nix = {
    system.configurationRevision = shortRev;
    system.nixos.label = "${shortRev}-${self.lastModifiedDate}";

    nix.gc = {
      automatic = true;
      dates = "daily";
      options = "--delete-older-than +5";
    };
  };
}
