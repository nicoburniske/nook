def usage [] {
  print "sumi - theme switcher runtime"
  print ""
  print "Usage:"
  print "  sumi [--manifest PATH] list"
  print "  sumi [--manifest PATH] current"
  print "  sumi [--manifest PATH] show <theme> [--json]"
  print "  sumi [--manifest PATH] switch <theme>"
  print "  sumi [--manifest PATH] doctor [theme]"
  print ""
  print "Environment:"
  print "  SUMI_MANIFEST        Path to manifest json"
  print "  SUMI_STATE_DIR       State directory (default: <manifest.home>/.local/state/sumi)"
  print "  SUMI_HOME_DIR        Home directory override (defaults to manifest.home)"
  print "  SUMI_LINK_BIN        Path to sumi-link binary"
  print "  SUMI_CONFLICT_POLICY Conflict policy: backup|replace"
}

def require_manifest [manifest_path: string] {
  if $manifest_path == "" {
    error make {msg: "sumi: manifest not configured. pass --manifest or set SUMI_MANIFEST"}
  }

  if not ($manifest_path | path exists) {
    error make {msg: $"sumi: manifest does not exist: ($manifest_path)"}
  }

  let manifest = (open $manifest_path)
  let env_home = ($env.SUMI_HOME_DIR? | default "")
  let home_dir = if $env_home != "" {
    $env_home
  } else if (($manifest.home? | default "") != "") {
    $manifest.home
  } else {
    ($env.HOME? | default "")
  }

  if $home_dir == "" {
    error make {msg: "sumi: could not resolve home directory"}
  }

  let env_state = ($env.SUMI_STATE_DIR? | default "")
  let state_dir = if $env_state != "" {
    $env_state
  } else {
    [$home_dir ".local" "state" "sumi"] | path join
  }

  {
    manifest_path: $manifest_path,
    manifest: $manifest,
    home_dir: $home_dir,
    state_dir: $state_dir,
  }
}

def ensure_theme_exists [manifest, theme: string] {
  if not (($manifest.themes | columns) | any {|key| $key == $theme}) {
    error make {msg: $"sumi: unknown theme '($theme)'"}
  }
}

def default_theme [manifest] {
  $manifest.defaultTheme? | default ""
}

def current_theme [ctx] {
  let current_path = [$ctx.state_dir "current.json"] | path join
  if ($current_path | path exists) {
    ((open $current_path).theme? | default "")
  } else {
    default_theme $ctx.manifest
  }
}

def list_themes [ctx] {
  for theme in ($ctx.manifest.themes | columns | sort) {
    print $theme
  }
}

def show_theme [ctx, theme: string, as_json: bool] {
  ensure_theme_exists $ctx.manifest $theme
  let theme_data = ($ctx.manifest.themes | get $theme)

  if $as_json {
    print ($theme_data | to json --indent 2)
  } else {
    print $"Theme: ($theme)"
    let polarity = ($theme_data.polarity? | default "unknown")
    let count = (($theme_data.files? | default []) | length)
    print $"  polarity: ($polarity)"
    print $"  files: ($count)"
  }
}

def doctor [ctx, requested_theme: string] {
  let theme = if $requested_theme != "" {
    $requested_theme
  } else {
    current_theme $ctx
  }

  if $theme == "" {
    error make {msg: "sumi: could not determine theme. pass one explicitly."}
  }

  ensure_theme_exists $ctx.manifest $theme
  let files = ((($ctx.manifest.themes | get $theme).files?) | default [])

  mut failures = 0
  for file in $files {
    let rel = ($file.path? | default "")
    let source = ($file.source? | default "")
    if $rel == "" { continue }

    let dest = [$ctx.home_dir $rel] | path join

    if not ($source | path exists) {
      print --stderr $"missing source: ($source)"
      $failures = ($failures + 1)
    }

    if ($dest | path exists) {
      let kind = ($dest | path type)
      if $kind != "symlink" {
        print --stderr $"non-symlink destination: ($dest)"
        $failures = ($failures + 1)
      }
    }
  }

  if $failures > 0 {
    exit 1
  }

  print $"sumi doctor: ok (($theme))"
}

def run_hooks_parallel [manifest] {
  let hooks = (($manifest.hooks?.reload?) | default [])
  let total = ($hooks | length)
  if $total == 0 {
    return
  }

  print "Running reload hooks in parallel..."

  let results = ($hooks | par-each {|hook|
    let registration = ($hook.registration? | default "unknown")
    let label = ($registration | str replace "program-" "")
    let command = ($hook.command? | default "")
    if $command == "" {
      {
        ok: true,
        label: $label,
        output: "",
      }
    } else {
      let complete = (do { ^bash -lc $command } | complete)
      {
        ok: ($complete.exit_code == 0),
        label: $label,
        output: (($complete.stderr | str trim) + (if (($complete.stdout | str trim) != "") { "\n" + ($complete.stdout | str trim) } else { "" })),
      }
    }
  })

  for r in $results {
    if $r.ok {
      print $"ok ($r.label)"
    } else {
      print --stderr $"warn ($r.label)"
      if ($r.output | str trim) != "" {
        print --stderr $r.output
      }
    }
  }

  let failed = ($results | where {|r| not $r.ok })
  if (($failed | length) > 0) {
    let labels = ($failed | get label | str join ", ")
    print --stderr $"Hook warnings (($failed | length)): ($labels)"
  }
}

def switch_theme [ctx, theme: string] {
  ensure_theme_exists $ctx.manifest $theme
  mkdir $ctx.state_dir

  print $"Linking theme files for '($theme)'..."

  let conflict_policy = (($env.SUMI_CONFLICT_POLICY? | default "backup"))
  let sumi_link_bin = (($env.SUMI_LINK_BIN? | default "sumi-link"))
  let lock_file = [$ctx.state_dir "switch.lock"] | path join

  let apply = (do {
    ^flock $lock_file $sumi_link_bin apply --manifest $ctx.manifest_path --state-dir $ctx.state_dir --theme $theme --conflict-policy $conflict_policy
  } | complete)

  if (($apply.stdout | str trim) != "") {
    print ($apply.stdout | str trim)
  }

  if $apply.exit_code != 0 and $apply.exit_code != 2 {
    if (($apply.stderr | str trim) != "") {
      print --stderr ($apply.stderr | str trim)
    }
    error make {msg: $"sumi: apply failed (status ($apply.exit_code))"}
  }

  if $apply.exit_code == 2 {
    print --stderr "sumi: apply completed with partial failures"
    if (($apply.stderr | str trim) != "") {
      print --stderr ($apply.stderr | str trim)
    }
  }

  run_hooks_parallel $ctx.manifest

  {
    theme: $theme,
    switchedAt: (date now | format date "%+"),
  } | to json | save --force ([$ctx.state_dir "current.json"] | path join)

  print $"Switched to theme '($theme)'"

  if $apply.exit_code == 2 {
    exit 2
  }
}

def main [--manifest: string, ...args: string] {
  let manifest_path = if (($manifest | default "") != "") {
    $manifest
  } else {
    ($env.SUMI_MANIFEST? | default "")
  }
  let parsed = {manifest: $manifest_path, rest: $args}
  let command = ($parsed.rest | get -o 0 | default "help")

  match $command {
    "help" => { usage }
    "-h" => { usage }
    "--help" => { usage }
    "list" => {
      let ctx = require_manifest $parsed.manifest
      list_themes $ctx
    }
    "current" => {
      let ctx = require_manifest $parsed.manifest
      print (current_theme $ctx)
    }
    "show" => {
      let ctx = require_manifest $parsed.manifest
      let theme = ($parsed.rest | get -o 1 | default "")
      if $theme == "" {
        error make {msg: "sumi: show requires a theme"}
      }
      let as_json = (($parsed.rest | get -o 2 | default "") == "--json")
      show_theme $ctx $theme $as_json
    }
    "switch" => {
      let ctx = require_manifest $parsed.manifest
      let theme = ($parsed.rest | get -o 1 | default "")
      if $theme == "" {
        error make {msg: "sumi: switch requires a theme"}
      }
      switch_theme $ctx $theme
    }
    "doctor" => {
      let ctx = require_manifest $parsed.manifest
      let theme = ($parsed.rest | get -o 1 | default "")
      doctor $ctx $theme
    }
    _ => {
      error make {msg: $"sumi: unknown command '($command)'"}
    }
  }
}
