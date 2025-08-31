{
  config,
  lib,
  pkgs,
  ...
}: let
  inherit (lib) mkOption types;
in {
  options.flakeRoot = {
    projectRootFile = mkOption {
      type = types.str;
      description = "The name of the unique file that exists only at project root";
      default = "flake.nix";
    };

    package = mkOption {
      type = types.package;
      readOnly = true;
      description = "The package providing the command to find the project root";
      default = pkgs.writeShellApplication {
        name = "flake-root";
        text = ''
          set -euo pipefail
          find_up() {
            ancestors=()
            while true; do
              if [[ -f $1 ]]; then
                echo "$PWD"
                exit 0
              fi
              ancestors+=("$PWD")
              if [[ $PWD == / ]] || [[ $PWD == // ]]; then
                echo "ERROR: Unable to locate the ${config.flakeRoot.projectRootFile} in any of: ''${ancestors[*]@Q}" >&2
                exit 1
              fi
              cd ..
            done
          }
          find_up "${config.flakeRoot.projectRootFile}"
        '';
      };
    };

    path = mkOption {
      type = types.str;
      readOnly = true;
      description = "The absolute path to the project root";
      default = "\$(${lib.getExe config.flakeRoot.package})";
    };
  };
}
