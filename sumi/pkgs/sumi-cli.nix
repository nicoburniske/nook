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
    home_dir="''${SUMI_HOME_DIR:-}"
    state_dir="''${SUMI_STATE_DIR:-}"
    sumi_link_bin="''${SUMI_LINK_BIN:-sumi-link}"

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
      SUMI_STATE_DIR  State directory (default: <manifest.home>/.local/state/sumi)
      SUMI_HOME_DIR   Home directory override (defaults to manifest.home)
      SUMI_LINK_BIN   Path to sumi-link binary
      SUMI_CONFLICT_POLICY Conflict policy: backup|replace
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

      local manifest_home
      manifest_home="$(jq -r '.home // empty' "$manifest")"

      if [ -z "$home_dir" ]; then
        if [ -n "$manifest_home" ]; then
          home_dir="$manifest_home"
        else
          home_dir="$HOME"
        fi
      fi

      if [ -z "$state_dir" ]; then
        state_dir="$home_dir/.local/state/sumi"
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

    switch_theme() {
      local theme="$1"
      local conflict_policy="''${SUMI_CONFLICT_POLICY:-backup}"
      local apply_status=0

      if ! jq -e --arg theme "$theme" '.themes[$theme] != null' "$manifest" >/dev/null; then
        echo "sumi: unknown theme '$theme'" >&2
        exit 1
      fi

      mkdir -p "$state_dir"

      echo "Linking theme files for '$theme'..."

      exec 9>"$state_dir/switch.lock"
      flock 9

      if "$sumi_link_bin" apply \
        --manifest "$manifest" \
        --state-dir "$state_dir" \
        --theme "$theme" \
        --conflict-policy "$conflict_policy"
      then
        apply_status=0
      else
        apply_status=$?
        if [ "$apply_status" -ne 2 ]; then
          echo "sumi: apply failed (status $apply_status)" >&2
          exit "$apply_status"
        fi
        echo "sumi: apply completed with partial failures" >&2
      fi

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

      if [ "$apply_status" -ne 0 ]; then
        exit "$apply_status"
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
        dest="$home_dir/$rel"

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
