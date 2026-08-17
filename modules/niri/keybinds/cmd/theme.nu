use ./lib.nu

const prefix = "theme"

export def entry [] {
  {
    prefix: $prefix
    root-row: (lib page-row $prefix "theme" $prefix)
    header: {|_state| {title: "cmd > theme", current: ""} }
    rows: {|_state| rows }
    apply: {|state, data| apply $state $data }
  }
}

def rows [] {
  let result = do { ^seni facets theme --json } | complete
  if $result.exit_code != 0 {
    return [
      (lib row "theme:none" "no themes found")
    ]
  }

  let data = $result.stdout | from json
  let current = $data | get current

  $data
  | get variants
  | sort
  | each {|theme|
    lib apply-row $"theme:($theme)" $theme "theme" {theme: $theme} ($theme == $current)
  }
}

def apply [state: record, data: record] {
  if ($data.kind? | default "") == "theme" and ($data.theme? | default "") != "" {
    ^seni switch $"theme=($data.theme)" | ignore
  }
  $state
}
