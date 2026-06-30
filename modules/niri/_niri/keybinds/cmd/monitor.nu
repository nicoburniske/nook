use ./lib.nu [action-row active-label module-row render-menu]

const prefix = "monitor"

const actions = {
  categories: $"($prefix):categories"
  values: $"($prefix):values"
  apply: $"($prefix):apply"
}

export def entry [] {
  {
    prefix: $prefix
    root-row: (module-row "monitor" $prefix)
    render: {||
      let available_outputs = outputs

      if ($available_outputs | length) == 1 {
        let output = $available_outputs | get 0
        render-menu $"cmd > monitor > ($output.name)" (list-categories $output.name)
      } else {
        render-menu "cmd > monitor" (
          $available_outputs
          | each {|output|
              action-row $output.label $actions.categories {output: $output.name}
            }
        )
      }
    }
    handle: {|action| handle $action }
  }
}

def handle [action: record] {
  if $action.kind == $actions.categories {
    (render-menu
      $"cmd > monitor > ($action.output)"
      (list-categories $action.output)
      (
        if ((outputs | length) == 1) {
          {kind: "root"}
        } else {
          {kind: "module", module: $prefix}
        }
      )
    )
  } else if $action.kind == $actions.values {
    (render-menu
      $"cmd > monitor > ($action.output) > ($action.category)"
      (list-values $action.output $action.category)
      {kind: $actions.categories, output: $action.output}
    )
  } else if $action.kind == $actions.apply {
    apply $action.output $action.category $action.value
    let base_prompt = $"cmd > monitor > ($action.output) > ($action.category)"
    let prompt = if $action.category == "brightness" { $"($base_prompt) (($action.value)%)" } else { $base_prompt }

    (render-menu
      $prompt
      (list-values $action.output $action.category)
      {kind: $actions.categories, output: $action.output}
    )
  }
}

def list-categories [output_name: string] {
  let output = output-by-name $output_name

  [
    {id: "brightness", label: "Brightness"}
    {id: "mode", label: "Mode"}
    {id: "scale", label: "Scale"}
  ]
  | append (
        if ($output.vrr_supported? | default false) { [
            {id: "vrr", label: "VRR"}
        ] } else { [] }
    )
  | sort-by label
  | each {|category|
      action-row $category.label $actions.values {
        output: $output_name
        category: $category.id
      }
    }
}

def list-values [output_name: string, category: string] {
  let output = output-by-name $output_name

  if $category == "mode" {
    mode-options $output
    | each {|mode|
          action-row (active-label $mode.label $mode.active) $actions.apply {
            output: $output_name
            category: "mode", 
            value: $mode.value
          }
        }
  } else if $category == "scale" {
    scale-options $output
    | each {|scale|
          action-row (active-label $scale.label $scale.active) $actions.apply {
            output: $output_name
            category: "scale", 
            value: $scale.value
          }
        }
  } else if $category == "vrr" {
    vrr-options $output
    | each {|vrr|
          action-row (active-label $vrr.label $vrr.active) $actions.apply {
            output: $output_name
            category: "vrr", 
            value: $vrr.value
          }
        }
  } else if $category == "brightness" {
    [
      "20"
      "40"
      "60"
      "80"
      "100"
    ]
    | each {|value|
        action-row $"($value)%" $actions.apply {
          output: $output_name
          category: "brightness", 
          value: $value
        }
      }
  } else {
    []
  }
}

def apply [output_name: string, category: string, value: string] {
  if $category == "mode" {
    niri msg output $output_name mode $value | ignore
  } else if $category == "scale" {
    niri msg output $output_name scale $value | ignore
  } else if $category == "vrr" {
    if $value == "on-demand" {
      niri msg output $output_name vrr on --on-demand | ignore
    } else {
      niri msg output $output_name vrr $value | ignore
    }
  } else if $category == "brightness" {
    ^sh -c '
      ddcutil setvcp 10 "$1" >/dev/null 2>&1 &
    ' sh $value | ignore
  }
}

def outputs [] {
  niri msg --json outputs
  | from json
  | transpose key output
  | each {|row|
        let output = $row.output
        let name = $output.name? | default $row.key
        let make = $output.make? | default ""
        let model = $output.model? | default ""
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
}

def output-by-name [output_name: string] {
  outputs | where name == $output_name | get 0
}

def mode-options [output: record] {
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

  let current_index = $output.current_mode? | default null
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

  $modes | each {|mode| $mode | merge {active: ($mode.label == $current_label)} }
}

def scale-options [output: record] {
  let current = (
    $output.logical.scale?
      | default ""
      | into string
      | str replace --regex '\.0$' ""
  )
  [
    "auto"
    "1"
    "1.25"
    "1.5"
    "1.6"
    "2"
    "3"
    "4"
  ]
  | each {|scale| {value: $scale, label: $scale, active: ($scale == $current)} }
}

def vrr-options [output: record] {
  let current = (
    if ($output.vrr_enabled? | default false) {
      "on"
    } else {
      "off"
    }
  )
  [
    {value: "on", label: "On"}
    {value: "on-demand", label: "On demand"}
    {value: "off", label: "Off"}
  ]
  | each {|vrr| $vrr | merge {active: ($vrr.value == $current)} }
}
