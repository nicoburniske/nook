{pkgs}:
pkgs.writeShellScriptBin "theme-switch" ''
  set -euo pipefail

  kitten quick-access-terminal \
    --instance-group theme-selector \
    ${pkgs.bash}/bin/bash -lc '
      set -euo pipefail
      themes=$(sumi list 2>/dev/null || true)

      theme=$(printf "%s\n" "$themes" | ${pkgs.fzf}/bin/fzf \
        --prompt="Select theme: " \
        --layout=reverse \
        --border=rounded \
        --color=dark)

      if [ -n "$theme" ]; then
        sumi switch "$theme"
      fi
    '
''
