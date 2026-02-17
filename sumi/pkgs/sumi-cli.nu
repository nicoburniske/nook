def usage [] {
  print "sumi - facet-based runtime config switching"
  print ""
  print "Usage:"
  print "  sumi [--manifest PATH] facets [facet]"
  print "  sumi [--manifest PATH] selection [--json]"
  print "  sumi [--manifest PATH] switch [facet=value]..."
  print "  sumi [--manifest PATH] doctor"
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

def default_selection [manifest] {
  $manifest.defaultSelection? | default {}
}

def normalize_selection [manifest selection] {
  let facets = ($manifest.facets? | default {})
  let defaults = (default_selection $manifest)
  mut out = {}

  for facet in (($facets | columns) | sort) {
    let facet_info = ($facets | get $facet)
    let variants = ((($facet_info.variants? | default {}) | columns) | sort)
    if (($variants | length) == 0) {
      continue
    }

    let manifest_default = ($facet_info.default? | default ($variants | get 0))
    let fallback = ($defaults | get -o $facet | default $manifest_default)
    let candidate = ($selection | get -o $facet | default $fallback)

    if ($variants | any {|value| $value == $candidate }) {
      $out = ($out | upsert $facet $candidate)
    } else if ($variants | any {|value| $value == $fallback }) {
      $out = ($out | upsert $facet $fallback)
    } else {
      $out = ($out | upsert $facet ($variants | get 0))
    }
  }

  $out
}

def get_selection [ctx] {
  let current_path = [$ctx.state_dir "current.json"] | path join
  let selection = if ($current_path | path exists) {
    (open $current_path).selection? | default (default_selection $ctx.manifest)
  } else {
    default_selection $ctx.manifest
  }

  normalize_selection $ctx.manifest $selection
}

def parse_selection_overrides [items: list<string>] {
  if (($items | length) == 0) {
    return {}
  }

  mut out = {}
  for item in $items {
    if not ($item | str contains "=") {
      error make {msg: $"sumi: invalid selection value '($item)', expected facet=value"}
    }
    let pair = ($item | split row "=" --number 2)
    let key = ($pair | get 0)
    let value = ($pair | get 1)
    if $key == "" or $value == "" {
      error make {msg: $"sumi: invalid selection value '($item)', expected facet=value"}
    }
    $out = ($out | upsert $key $value)
  }
  $out
}

def facets_cmd [ctx, requested_facet: string] {
  let facets = ($ctx.manifest.facets? | default {})
  if $requested_facet != "" {
    if not (($facets | columns) | any {|f| $f == $requested_facet }) {
      error make {msg: $"sumi: unknown facet '($requested_facet)'"}
    }
    for v in (((($facets | get $requested_facet).variants | columns) | sort)) {
      print $v
    }
    return
  }

  for facet in (($facets | columns) | sort) {
    let def = ((($facets | get $facet).default?) | default "")
    let count = (((($facets | get $facet).variants | columns) | length) | into string)
    print $"($facet) default=($def) variants=($count)"
  }
}

def selection_cmd [ctx, as_json: bool] {
  let selection = (get_selection $ctx)
  if $as_json {
    print ($selection | to json --indent 2)
  } else {
    for key in (($selection | columns) | sort) {
      print $"($key)=($selection | get $key)"
    }
  }
}

def rule_matches [rule selection] {
  let when = ($rule.when? | default {})
  if (($when | columns | length) == 0) {
    true
  } else {
    (($when | columns) | all {|facet|
      let allowed = ($when | get $facet)
      let selected = ($selection | get -o $facet | default "")
      ($allowed | any {|v| $v == $selected })
    })
  }
}

def run_hooks_parallel [manifest selection] {
  let hooks = (($manifest.hooks?.reload?) | default [])
  let matching = ($hooks | where {|hook| rule_matches { when: ($hook.when? | default {}) } $selection })
  if (($matching | length) == 0) {
    return
  }

  print "Running reload hooks in parallel..."
  let results = ($matching | par-each {|hook|
    let registration = ($hook.registration? | default "unknown")
    let label = ($registration | str replace "program-" "")
    let command = ($hook.command? | default "")
    if $command == "" {
      { ok: true, label: $label, output: "" }
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
    print --stderr $"Hook warnings (($failed | length)): (($failed | get label | str join ', '))"
  }
}

def switch_cmd [ctx, args: list<string>] {
  if not ($ctx.state_dir | path exists) {
    mkdir $ctx.state_dir
  }

  let current = (get_selection $ctx)
  let overrides = (parse_selection_overrides $args)
  let selection = (normalize_selection $ctx.manifest ($current | merge $overrides))

  let conflict_policy = (($env.SUMI_CONFLICT_POLICY? | default "backup"))
  let sumi_link_bin = (($env.SUMI_LINK_BIN? | default "sumi-link"))
  let lock_file = [$ctx.state_dir "switch.lock"] | path join

  mut apply_args = ["apply" "--manifest" $ctx.manifest_path "--state-dir" $ctx.state_dir "--conflict-policy" $conflict_policy]
  for key in (($selection | columns) | sort) {
    $apply_args = ($apply_args | append ["--set" $"($key)=($selection | get $key)"])
  }
  let run_args = $apply_args

  print "Linking selection files..."
  let apply = (do { ^flock $lock_file $sumi_link_bin ...$run_args } | complete)

  if (($apply.stdout | str trim) != "") {
    print ($apply.stdout | str trim)
  }

  if $apply.exit_code != 0 and $apply.exit_code != 2 {
    if (($apply.stderr | str trim) != "") {
      print --stderr ($apply.stderr | str trim)
    }
    error make {msg: ("sumi: apply failed (status " + (($apply.exit_code | into string)) + ")")}
  }

  if $apply.exit_code == 2 {
    print --stderr "sumi: apply completed with partial failures"
    if (($apply.stderr | str trim) != "") {
      print --stderr ($apply.stderr | str trim)
    }
  }

  run_hooks_parallel $ctx.manifest $selection

  {
    selection: $selection,
    switchedAt: (date now | format date "%+"),
  } | to json | save --force ([$ctx.state_dir "current.json"] | path join)

  print "Switched selection"
  if $apply.exit_code == 2 {
    exit 2
  }
}

def doctor_cmd [ctx] {
  let selection = (get_selection $ctx)
  mut failures = 0
  for file in ($ctx.manifest.files? | default []) {
    let selected_rule = (($file.rules? | default []) | where {|r| rule_matches $r $selection } | get -o 0)
    if ($selected_rule | is-empty) { continue }

    let source = ($selected_rule.source? | default "")
    let rel = ($file.path? | default "")
    if $rel == "" { continue }
    let dest = [$ctx.home_dir $rel] | path join

    if not ($source | path exists) {
      print --stderr $"missing source: ($source)"
      $failures = ($failures + 1)
    }
    if ($dest | path exists) and (($dest | path type) != "symlink") {
      print --stderr $"non-symlink destination: ($dest)"
      $failures = ($failures + 1)
    }
  }

  if $failures > 0 {
    exit 1
  }
  print "sumi doctor: ok"
}

def main [--manifest: string, --json, ...args: string] {
  let manifest_path = if (($manifest | default "") != "") { $manifest } else { ($env.SUMI_MANIFEST? | default "") }
  let command = ($args | get -o 0 | default "help")
  let rest = ($args | skip 1)

  if ($command == "help" or $command == "-h" or $command == "--help") {
    usage
    return
  }

  let ctx = require_manifest $manifest_path
  match $command {
    "facets" => {
      facets_cmd $ctx ($rest | get -o 0 | default "")
    }
    "selection" => {
      if (($rest | length) > 0) {
        error make {msg: "sumi: selection takes no positional args"}
      }
      selection_cmd $ctx $json
    }
    "switch" => {
      switch_cmd $ctx $rest
    }
    "doctor" => {
      if (($rest | length) > 0) {
        error make {msg: "sumi: doctor does not accept arguments"}
      }
      doctor_cmd $ctx
    }
    _ => {
      error make {msg: $"sumi: unknown command '($command)'"}
    }
  }
}
