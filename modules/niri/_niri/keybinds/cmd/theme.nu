use ./lib.nu [action-row module-row render-menu]

const prefix = "theme"

const actions = {
  apply: $"($prefix):apply"
}

export def entry [] {
  {
    prefix: $prefix
    root-row: (module-row "theme" $prefix)
    render: {|| render-menu "cmd > theme" (list-themes) }
    handle: {|action| handle $action }
  }
}

def handle [action: record] {
  if $action.kind == $actions.apply {
    apply $action.theme
  }
}

def list-themes [] {
  let themes_result = do { ^sumi facets theme --json } | complete

  if $themes_result.exit_code != 0 {
    return []
  }

  let theme_data = $themes_result.stdout | from json
  let current_theme = $theme_data | get current

  $theme_data
  | get variants
  | sort
  | each {|theme|
        let label = (if $theme == $current_theme { $"* ($theme)" } else { $"  ($theme)" })
        action-row $label $actions.apply {theme: $theme}
      }
}

def apply [theme: string] {
  if $theme != "" {
    ^sumi switch $"theme=($theme)" | ignore
  }
}
