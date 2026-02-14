{
  bash,
  writeShellApplication,
  coreutils,
  jq,
  util-linux,
}:
writeShellApplication {
  name = "sumi";

  runtimeInputs = [
    bash
    coreutils
    jq
    util-linux
  ];

  text = ''
    set -euo pipefail

    manifest="''${SUMI_MANIFEST:-}"
    home_dir="''${SUMI_HOME_DIR:-$HOME}"
    config_dir="''${SUMI_CONFIG_DIR:-$home_dir/.config}"
    state_dir="''${SUMI_STATE_DIR:-$home_dir/.local/state/sumi}"

    usage() {
      cat <<'EOF'
    sumi - theme switcher runtime

    Usage:
      sumi [--manifest PATH] list
      sumi [--manifest PATH] current
      sumi [--manifest PATH] show <theme> [--json]
      sumi [--manifest PATH] switch <theme>
      sumi [--manifest PATH] doctor [theme]

    Environment:
      SUMI_MANIFEST   Path to manifest json
      SUMI_STATE_DIR  State directory (default: $HOME/.local/state/sumi)
      SUMI_HOME_DIR   Home directory used for managed paths
      SUMI_CONFIG_DIR Config directory used for .config paths
    EOF
    }

    require_manifest() {
      if [ -z "$manifest" ]; then
        echo "sumi: manifest not configured. pass --manifest or set SUMI_MANIFEST" >&2
        exit 1
      fi

      if [ ! -f "$manifest" ]; then
        echo "sumi: manifest does not exist: $manifest" >&2
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
        echo "sumi: unknown theme '$theme'" >&2
        exit 1
      fi

      mkdir -p "$state_dir"

      echo "Linking theme files for '$theme'..."

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

        tmp_link="''${dest}.sumi.tmp.$$"
        ln -sfn "$source" "$tmp_link"
        mv -Tf "$tmp_link" "$dest"
      done < <(jq -r --arg theme "$theme" '.themes[$theme].files[]? | "\(.path)\t\(.source)"' "$manifest")

      local total_hooks
      local hook_index=0
      local hook_failures=0
      local -a failed_hooks=()

      total_hooks="$(jq -r '(.hooks.reload // []) | length' "$manifest")"

      if [ "$total_hooks" -gt 0 ]; then
        echo "Running reload hooks..."
      fi

      while IFS=$'\t' read -r hook_registration hook_command; do
        [ -n "$hook_command" ] || continue

        hook_index=$((hook_index + 1))

        local hook_label="''${hook_registration#program-}"
        local hook_output=""

        if hook_output="$(${bash}/bin/bash -lc "$hook_command" 2>&1)"; then
          echo "[$hook_index/$total_hooks] $hook_label"
        else
          echo "[$hook_index/$total_hooks] fail $hook_label" >&2
          if [ -n "$hook_output" ]; then
            echo "$hook_output" >&2
          fi
          hook_failures=$((hook_failures + 1))
          failed_hooks+=("$hook_label")
        fi
      done < <(jq -r '(.hooks.reload // [])[] | [(.registration // "unknown"), .command] | @tsv' "$manifest")

      printf '{"theme":"%s","switchedAt":"%s"}\n' "$theme" "$(date --iso-8601=seconds)" > "$state_dir/current.json"

      echo "Switched to theme '$theme'"

      if [ "$hook_failures" -gt 0 ]; then
        echo "Hook failures ($hook_failures): ''${failed_hooks[*]}" >&2
      fi
    }

    show_theme() {
      local theme="$1"
      local json="''${2:-false}"

      if ! jq -e --arg theme "$theme" '.themes[$theme] != null' "$manifest" >/dev/null; then
        echo "sumi: unknown theme '$theme'" >&2
        exit 1
      fi

      if [ "$json" = "true" ]; then
        jq --arg theme "$theme" '.themes[$theme]' "$manifest"
        return
      fi

      echo "Theme: $theme"
      jq -r --arg theme "$theme" '.themes[$theme] | "  polarity: \(.polarity)\n  files: \(.files | length)"' "$manifest"
    }

    doctor() {
      local theme="''${1:-}"
      local failures=0

      if [ -z "$theme" ]; then
        theme="$(current_theme)"
      fi

      if [ -z "$theme" ]; then
        echo "sumi: could not determine theme. pass one explicitly." >&2
        exit 1
      fi

      if ! jq -e --arg theme "$theme" '.themes[$theme] != null' "$manifest" >/dev/null; then
        echo "sumi: unknown theme '$theme'" >&2
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

      echo "sumi doctor: ok ($theme)"
    }

    parse_global_args() {
      while [ "$#" -gt 0 ]; do
        case "$1" in
          --manifest)
            if [ "$#" -lt 2 ]; then
              echo "sumi: --manifest requires a path" >&2
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
          echo "sumi: show requires a theme" >&2
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
          echo "sumi: switch requires a theme" >&2
          exit 1
        fi
        switch_theme "$2"
        ;;
      doctor)
        require_manifest
        doctor "''${2:-}"
        ;;
      *)
        echo "sumi: unknown command '$command'" >&2
        usage >&2
        exit 1
        ;;
    esac
  '';
}
