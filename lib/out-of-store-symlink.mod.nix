{
  commonModules.lib.nixpkgs.overlays = [
    (final: prev: {
      mkOutOfStoreSymlink = path: let
        string = toString path;
      in
        prev.runCommandLocal (final.lib.strings.sanitizeDerivationName "out-of-store-${baseNameOf string}") {} ''
          ln -s ${final.lib.escapeShellArg string} "$out"
        '';
    })
  ];
}
