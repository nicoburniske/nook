{pkgs, ...}: let
  themeSwitch = pkgs.writeShellScriptBin "theme-switch" ''
    #!/usr/bin/env bash
    set -euo pipefail

    themes=$(velum list 2>/dev/null || echo "")

    if [ -z "$themes" ]; then
      echo "No themes available"
      exit 1
    fi

    THEME=$(echo "$themes" | ${pkgs.fzf}/bin/fzf \
      --prompt="Select theme: " \
      --layout=reverse \
      --border=rounded \
      --color=dark)

    # Exit if no selection made
    if [ -z "$THEME" ]; then
      exit 0
    fi

    echo "Switching to $THEME theme..."
    velum switch "$THEME"
  '';

  kittyThemeSwitch = pkgs.writeShellScriptBin "kitty-theme-switch" ''
    #!/usr/bin/env bash
    set -euo pipefail

    kitten quick-access-terminal \
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
