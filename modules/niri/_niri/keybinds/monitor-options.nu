export def main [] {
  let outputs = (
    niri msg --json outputs
      | from json
      | transpose key output
      | each {|row|
          let output = $row.output
          let name = ($output.name? | default $row.key)
          let make = ($output.make? | default "")
          let model = ($output.model? | default "")
          let label = (
            if $model != "" and $make != "" {
              $"($name) - ($make) ($model)"
            } else if $model != "" {
              $"($name) - ($model)"
            } else {
              $name
            }
          )

          $output | merge {name: $name, label: $label}
        }
      | sort-by name
  )

  if ($outputs | is-empty) {
    exit 0
  }

  let output_name = (
    if (($outputs | length) == 1) {
      $outputs | get 0.name
    } else {
      $outputs
        | each {|output| row $output.name $output.label }
        | str join "\n"
        | choose "output> "
    }
  )

  let output = ($outputs | where name == $output_name | get 0)
  let categories = (
    [
      {id: "mode", label: "Mode"}
      {id: "scale", label: "Scale"}
    ]
    | append (if ($output.vrr_supported? | default false) { [{id: "vrr", label: "VRR"}] } else { [] })
    | sort-by label
  )
  let category = (
    $categories
      | each {|category| row $category.id $category.label }
      | str join "\n"
      | choose $"($output_name)> "
  )

  if $category == "mode" {
    set-mode $output_name $output
  } else if $category == "scale" {
    set-scale $output_name $output
  } else if $category == "vrr" {
    set-vrr $output_name $output
  }
}

def set-mode [output_name: string, output: record] {
  let modes = (
    $output.modes
      | each {|mode|
          let refresh_hz = ($mode.refresh_rate / 1000.0)
          let value = $"($mode.width)x($mode.height)@($refresh_hz)"

          {
            value: $value
            label: $"($mode.width)x($mode.height) @ ($refresh_hz)Hz"
            pixels: ($mode.width * $mode.height)
            width: $mode.width
            height: $mode.height
            refresh_rate: $mode.refresh_rate
          }
        }
      | uniq-by value
      | sort-by --reverse pixels width height refresh_rate
  )

  if ($modes | is-empty) {
    exit 0
  }

  let current_index = ($output.current_mode? | default null)
  let current = (
    if $current_index == null {
      null
    } else {
      $output.modes | get -o $current_index | default null
    }
  )
  let current_label = (
    if $current == null {
      ""
    } else {
      let refresh_hz = ($current.refresh_rate / 1000.0)
      $"($current.width)x($current.height) @ ($refresh_hz)Hz"
    }
  )
  let mode = (
    $modes
      | each {|mode| row $mode.value (active-label $mode.label ($mode.label == $current_label)) }
      | str join "\n"
      | choose "mode> " --selected (active-label $current_label true)
  )

  niri msg output $output_name mode $mode | ignore
}

def set-scale [output_name: string, output: record] {
  let current = (
    $output.logical.scale?
      | default ""
      | into string
      | str replace --regex '\.0$' ""
  )
  let scale = (
    ["auto" "1" "1.25" "1.5" "1.6" "2"]
      | each {|scale| row $scale (active-label $scale ($scale == $current)) }
      | str join "\n"
      | choose "scale> " --selected (active-label $current true)
  )

  niri msg output $output_name scale $scale | ignore
}

def set-vrr [output_name: string, output: record] {
  let current = (
    if ($output.vrr_enabled? | default false) {
      "on"
    } else {
      "off"
    }
  )
  let vrr = (
    [
      {id: "on", label: "On"}
      {id: "on-demand", label: "On demand"}
      {id: "off", label: "Off"}
    ]
    | each {|vrr| row $vrr.id (active-label $vrr.label ($vrr.id == $current)) }
    | str join "\n"
    | choose "vrr> " --selected (active-label ($current | str title-case) true)
  )

  if $vrr == "on-demand" {
    niri msg output $output_name vrr on --on-demand | ignore
  } else {
    niri msg output $output_name vrr $vrr | ignore
  }
}

def row [value: string, label: string] {
  [$value $label] | str join "\t"
}

def active-label [label: string, active: bool] {
  if $active {
    $"* ($label)"
  } else {
    $"  ($label)"
  }
}

def choose [
  prompt: string
  --selected: string = ""
] {
  let menu = $in
  let selected_arg = (
    if ($selected | is-empty) {
      []
    } else {
      [$"--select=($selected)"]
    }
  )
  let result = (
    do {
      $menu
        | fuzzel --dmenu --prompt $prompt --match-mode exact --with-nth 2 --accept-nth 1 --match-nth 2 --only-match ...$selected_arg
    } | complete
  )

  if $result.exit_code != 0 {
    exit 0
  }

  let selection = ($result.stdout | str trim)
  if ($selection | is-empty) {
    exit 0
  }

  $selection
}
