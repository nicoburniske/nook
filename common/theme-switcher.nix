{
  pkgs,
  config,
  ...
}: let
  themeSwitch = pkgs.writeShellScriptBin "theme-switch" ''
    #!/usr/bin/env bash
    set -euo pipefail

    SPEC_DIR="$HOME/specialisation"

    if [ ! -d "$SPEC_DIR" ]; then
      echo "No specialisations found."
      exit 1
    fi

    themes=$(ls -1 "$SPEC_DIR" 2>/dev/null || echo "")

    if [ -z "$themes" ]; then
      echo "No themes available"
      exit 1
    fi

    THEME=$(echo "$themes" | ${pkgs.fzf}/bin/fzf \
      --prompt="Select theme: " \
      --height=80% \
      --layout=reverse \
      --border=rounded \
      --color=dark)

    # Exit if no selection made
    if [ -z "$THEME" ]; then
      exit 0
    fi

    if [ ! -e "$SPEC_DIR/$THEME" ]; then
      echo "Error: Theme '$THEME' not found"
      exit 1
    fi

    echo "Switching to $THEME theme..."
    "$SPEC_DIR/$THEME/activate"
  '';

  kittyPkg = config.programs.kitty.package or pkgs.kitty;

  kittyThemeSwitch = pkgs.writeShellScriptBin "kitty-theme-switch" ''
    #!/usr/bin/env bash
    set -euo pipefail

    ${kittyPkg}/bin/kitten quick-access-terminal \
      --config ~/.config/kitty/quick-access-teriminal-center.conf \
      --instance-group theme-selector \
      ${themeSwitch}/bin/theme-switch
  '';
in {
  # Activation script to maintain specialisation symlink
  home.activation.specialisationSetup = ''
    if [[ -e $newGenPath/specialisation ]]; then
      test -h specialisation && unlink specialisation
      ln -s $newGenPath/specialisation
    fi
  '';

  home.packages = [themeSwitch kittyThemeSwitch];
}
