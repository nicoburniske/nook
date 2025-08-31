{ pkgs, ... }: {
  # Activation script to maintain specialisation symlink
  home.activation.specialisationSetup = ''
    if [[ -e $newGenPath/specialisation ]]; then
      test -h specialisation && unlink specialisation
      ln -s $newGenPath/specialisation
    fi
  '';

  home.packages = with pkgs; [
    (writeShellScriptBin "theme-switch" ''
      #!/usr/bin/env bash
      set -euo pipefail
      
      THEME="''${1:-}"
      SPEC_DIR="$HOME/specialisation"
      
      if [ ! -d "$SPEC_DIR" ]; then
        echo "No specialisations found. Run 'just home' first."
        exit 1
      fi
      
      if [ -z "$THEME" ]; then
        echo "Available themes:"
        ls "$SPEC_DIR" | sed 's/^/  /'
        echo ""
        echo "Usage: theme-switch <theme>"
        exit 0
      fi
      
      if [ ! -e "$SPEC_DIR/$THEME" ]; then
        echo "Error: Theme '$THEME' not found"
        echo "Available themes:"
        ls "$SPEC_DIR" | sed 's/^/  /'
        exit 1
      fi
      
      echo "Switching to $THEME theme..."
      "$SPEC_DIR/$THEME/activate"
    '')
  ];
}