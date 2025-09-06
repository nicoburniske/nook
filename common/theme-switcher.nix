{pkgs, ...}: let
  # Determine which theme selector to use based on platform
  themeSelectorLogic =
    if pkgs.stdenv.isLinux
    then ''
      THEME=$(echo "$themes" | ${pkgs.walker}/bin/walker \
        --dmenu \
        -p "Select theme:")
    ''
    else ''
      THEME=$(echo "$themes" | fzf \
        --prompt="Select theme: " \
        --height=40% \
        --layout=reverse)
    '';

  themeSwitchScript = pkgs.writeShellScriptBin "theme-switch" ''
    #!/usr/bin/env bash
    set -euo pipefail

    THEME="''${1:-}"
    SPEC_DIR="$HOME/specialisation"

    if [ ! -d "$SPEC_DIR" ]; then
      echo "No specialisations found."
      exit 1
    fi

    if [ -z "$THEME" ]; then
      themes=$(ls -1 "$SPEC_DIR" 2>/dev/null || echo "")

      if [ -z "$themes" ]; then
        echo "No themes available"
        exit 1
      fi

      ${themeSelectorLogic}

      # Exit if no selection made
      if [ -z "$THEME" ]; then
        exit 0
      fi
    fi

    if [ ! -e "$SPEC_DIR/$THEME" ]; then
      echo "Error: Theme '$THEME' not found"
      exit 1
    fi

    echo "Switching to $THEME theme..."
    "$SPEC_DIR/$THEME/activate"
  '';
in {
  # Activation script to maintain specialisation symlink
  home.activation.specialisationSetup = ''
    if [[ -e $newGenPath/specialisation ]]; then
      test -h specialisation && unlink specialisation
      ln -s $newGenPath/specialisation
    fi
  '';

  home.packages = [themeSwitchScript];
}
