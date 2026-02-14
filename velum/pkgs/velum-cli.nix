{
  bash,
  writeShellApplication,
  coreutils,
  jq,
  util-linux,
}:
writeShellApplication {
  name = "velum";

  runtimeInputs = [
    bash
    coreutils
    jq
    util-linux
  ];

  text = ''
    set -euo pipefail

    manifest="''${VELUM_MANIFEST:-}"
    home_dir="''${VELUM_HOME_DIR:-$HOME}"
    config_dir="''${VELUM_CONFIG_DIR:-$home_dir/.config}"
    state_dir="''${VELUM_STATE_DIR:-$home_dir/.local/state/velum}"

    usage() {
      cat <<'EOF'
    velum - theme switcher runtime

    Usage:
      velum [--manifest PATH] list
      velum [--manifest PATH] current
      velum [--manifest PATH] show <theme> [--json]
      velum [--manifest PATH] switch <theme>
      velum [--manifest PATH] doctor [theme]

    Environment:
      VELUM_MANIFEST   Path to manifest json
      VELUM_STATE_DIR  State directory (default: $HOME/.local/state/velum)
      VELUM_HOME_DIR   Home directory used for managed paths
      VELUM_CONFIG_DIR Config directory used for .config paths
    EOF
    }

    require_manifest() {
      if [ -z "$manifest" ]; then
        echo "velum: manifest not configured. pass --manifest or set VELUM_MANIFEST" >&2
        exit 1
      fi

      if [ ! -f "$manifest" ]; then
        echo "velum: manifest does not exist: $manifest" >&2
        exit 1
      fi
    }

    list_themes() {
      jq -r '.themes | keys[]' "$manifest"
    }

    default_theme() {
      jq -r '.defaultTheme // empty' "$manifest"
    }

    current_theme() {
      if [ -f "$state_dir/current.json" ]; then
        jq -r '.theme // empty' "$state_dir/current.json"
        return 0
      fi

      default_theme
    }

    resolve_destination() {
      local path="$1"

      if [[ "$path" = /* ]]; then
        printf '%s\n' "$path"
      elif [[ "$path" = .config/* ]]; then
        printf '%s/%s\n' "$config_dir" "''${path#.config/}"
      else
        printf '%s/%s\n' "$home_dir" "$path"
      fi
    }

    switch_theme() {
      local theme="$1"

      if ! jq -e --arg theme "$theme" '.themes[$theme] != null' "$manifest" >/dev/null; then
        echo "velum: unknown theme '$theme'" >&2
        exit 1
      fi

      mkdir -p "$state_dir"

      exec 9>"$state_dir/switch.lock"
      flock 9

      while IFS=$'\t' read -r rel source; do
        [ -n "$rel" ] || continue

        local dest
        local tmp_link

        dest="$(resolve_destination "$rel")"

        mkdir -p "$(dirname "$dest")"

        if [ -d "$dest" ] && [ ! -L "$dest" ]; then
          rm -rf "$dest"
        elif [ -e "$dest" ] && [ ! -L "$dest" ]; then
          rm -f "$dest"
        fi

        tmp_link="''${dest}.velum.tmp.$$"
        ln -sfn "$source" "$tmp_link"
        mv -Tf "$tmp_link" "$dest"
      done < <(jq -r --arg theme "$theme" '.themes[$theme].files[]? | "\(.path)\t\(.source)"' "$manifest")

      while IFS= read -r command; do
        [ -n "$command" ] || continue
        ${bash}/bin/bash -lc "$command"
      done < <(jq -r '.hooks.reload[]?.command' "$manifest")

      printf '{"theme":"%s","switchedAt":"%s"}\n' "$theme" "$(date --iso-8601=seconds)" > "$state_dir/current.json"
      echo "Switched to theme '$theme'"
    }

    show_theme() {
      local theme="$1"
      local json="''${2:-false}"

      if ! jq -e --arg theme "$theme" '.themes[$theme] != null' "$manifest" >/dev/null; then
        echo "velum: unknown theme '$theme'" >&2
        exit 1
      fi

      if [ "$json" = "true" ]; then
        jq --arg theme "$theme" '.themes[$theme]' "$manifest"
        return
      fi

      echo "Theme: $theme"
      jq -r --arg theme "$theme" '.themes[$theme] | "  slug: \(.slug)\n  polarity: \(.polarity)\n  files: \(.files | length)"' "$manifest"
    }

    doctor() {
      local theme="''${1:-}"
      local failures=0

      if [ -z "$theme" ]; then
        theme="$(current_theme)"
      fi

      if [ -z "$theme" ]; then
        echo "velum: could not determine theme. pass one explicitly." >&2
        exit 1
      fi

      if ! jq -e --arg theme "$theme" '.themes[$theme] != null' "$manifest" >/dev/null; then
        echo "velum: unknown theme '$theme'" >&2
        exit 1
      fi

      while IFS=$'\t' read -r rel source; do
        [ -n "$rel" ] || continue

        local dest
        dest="$(resolve_destination "$rel")"

        if [ ! -e "$source" ]; then
          echo "missing source: $source" >&2
          failures=1
        fi

        if [ -e "$dest" ] && [ ! -L "$dest" ]; then
          echo "non-symlink destination: $dest" >&2
          failures=1
        fi
      done < <(jq -r --arg theme "$theme" '.themes[$theme].files[]? | "\(.path)\t\(.source)"' "$manifest")

      if [ "$failures" -ne 0 ]; then
        exit 1
      fi

      echo "velum doctor: ok ($theme)"
    }

    parse_global_args() {
      while [ "$#" -gt 0 ]; do
        case "$1" in
          --manifest)
            if [ "$#" -lt 2 ]; then
              echo "velum: --manifest requires a path" >&2
              exit 1
            fi
            manifest="$2"
            shift 2
            ;;
          -h|--help)
            usage
            exit 0
            ;;
          *)
            break
            ;;
        esac
      done

      REMAINING_ARGS=("$@")
    }

    parse_global_args "$@"
    set -- "''${REMAINING_ARGS[@]}"

    command="''${1:-help}"

    case "$command" in
      help|-h|--help)
        usage
        ;;
      list)
        require_manifest
        list_themes
        ;;
      current)
        require_manifest
        current_theme
        ;;
      show)
        require_manifest
        if [ "$#" -lt 2 ]; then
          echo "velum: show requires a theme" >&2
          exit 1
        fi
        if [ "''${3:-}" = "--json" ]; then
          show_theme "$2" true
        else
          show_theme "$2" false
        fi
        ;;
      switch)
        require_manifest
        if [ "$#" -lt 2 ]; then
          echo "velum: switch requires a theme" >&2
          exit 1
        fi
        switch_theme "$2"
        ;;
      doctor)
        require_manifest
        doctor "''${2:-}"
        ;;
      *)
        echo "velum: unknown command '$command'" >&2
        usage >&2
        exit 1
        ;;
    esac
  '';
}
