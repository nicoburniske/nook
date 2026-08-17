{
  homeModules.eden = {pkgs, ...}: let
    nx-optimizer-src = pkgs.fetchurl {
      url = "https://github.com/MaxLastBreath/nx-optimizer/releases/download/manager-3.2.0/NX.Optimizer.3.2.0.AppImage";
      hash = "sha256-a29nCz9KbGFd2vhrMMMUUycKrWqIPCBEO7tFoyaxdNg=";
    };

    nx-optimizer-bin = pkgs.runCommandLocal "nx-optimizer-bin" {} ''
      mkdir -p $out/bin
      cp ${nx-optimizer-src} $out/bin/nx-optimizer-bin
      chmod +x $out/bin/nx-optimizer-bin
    '';

    nx-optimizer-run = pkgs.writeShellScript "nx-optimizer-run" ''
      set -euo pipefail

      config_dir="''${XDG_CONFIG_HOME:-$HOME/.config}/nx-optimizer"

      mkdir -p "$config_dir"
      cd "$config_dir"

      exec ${nx-optimizer-bin}/bin/nx-optimizer-bin "$@"
    '';

    nx-optimizer = pkgs.buildFHSEnv {
      name = "nx-optimizer";
      targetPkgs = pkgs:
        with pkgs; [
          fontconfig
          freetype
          libx11
          libxcb
          libxext
          libxft
          libxrender
          zlib
          xclip
        ];
      runScript = "${nx-optimizer-run}";
    };
  in {
    packages = [
      pkgs.eden
      nx-optimizer
    ];
  };
}
