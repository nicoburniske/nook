{...}: {
  perSystem = {pkgs, ...}: let
    phoronixKernel = pkgs.mkShell {
      packages = with pkgs;
        [
          phoronix-test-suite
          pkg-config
        ]
        ++ linux.nativeBuildInputs
        ++ linux.moduleBuildDependencies;
      hardeningDisable = ["all"];
      shellHook = ''
        unset NIX_CFLAGS_COMPILE NIX_CFLAGS_COMPILE_FOR_BUILD NIX_CFLAGS_COMPILE_FOR_TARGET
        unset NIX_LDFLAGS NIX_LDFLAGS_FOR_BUILD NIX_LDFLAGS_FOR_TARGET
      '';
    };
  in {
    devShells.phoronix-kernel = phoronixKernel;
  };
}
