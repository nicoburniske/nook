use ./lib.nu

const prefix = "monitor"

const hdr_value_categories = [
  "hdr-reference-luminance"
  "sdr-brightness"
  "sdr-saturation"
]

export def entry [] {
  {
    prefix: $prefix
    root-row: (lib page-row $prefix "monitor" $prefix)
    header: {|state| header $state }
    rows: {|state| rows $state }
    apply: {|state, data| apply $state $data }
  }
}

def header [state: record] {
  match $state.page {
    "monitor" => { {title: "cmd > monitor", current: ""} }
    "monitor:category" => {
      {
        title: $"cmd > monitor > ($state.data.output)"
        current: ""
      }
    }
    "monitor:value" => {
      let base = $"cmd > monitor > ($state.data.output) > ($state.data.category)"
      {
        title: $base
        current: (current-value-label $state.data.output $state.data.category)
      }
    }
    _ => { {title: "cmd > monitor", current: ""} }
  }
}

def rows [state: record] {
  match $state.page {
    "monitor" => {
      let available = outputs
      if ($available | is-empty) {
        [
          (lib row "monitor:none" "no outputs found")
        ]
      } else if ($available | length) == 1 {
        category-rows ($available | get 0.name)
      } else {
        $available | each {|output|
          lib page-row $"monitor:output:($output.name)" $output.label "monitor:category" "" {output: $output.name}
        }
      }
    }
    "monitor:category" => { category-rows $state.data.output }
    "monitor:value" => { value-rows $state }
    _ => { [] }
  }
}

def apply [state: record, data: record] {
  mut next = $state
  run-action $data.output $data.category $data.value
  $next.data = $state.data | merge {selected: $data.value}
  $next
}

def category-rows [output_name: string] {
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
  | append (
    if ($output.hdr_supported? | default false) { [
      {id: "hdr-mode", label: "HDR mode"}
      {id: "hdr-reference-luminance", label: "HDR reference luminance"}
      {id: "sdr-brightness", label: "SDR brightness"}
      {id: "sdr-saturation", label: "SDR saturation"}
    ] } else { [] }
  )
  | each {|category|
    lib page-row $"monitor:category:($category.id)" $category.label "monitor:value" "" {
      output: $output_name
      category: $category.id
    }
  }
}

def value-rows [state: record] {
  let output_name = $state.data.output
  let category = $state.data.category
  let output = output-by-name $output_name
  let selected = (
    $state.data
    | get -o selected
    | default (current-value $output $category)
    | into string
    | str downcase
  )

  match $category {
    "mode" => { mode-options $output }
    "scale" => { scale-options $output }
    "vrr" => { vrr-options $output }
    "brightness" => {
      ["20" "40" "60" "80" "100"] | each {|value| {value: $value, label: $"($value)%", active: ($value == $selected)} }
    }
    "hdr-mode" => {
      [
        {value: "off", label: "Off"}
        {value: "auto", label: "Auto"}
        {value: "on", label: "On"}
      ]
      | each {|option| $option | merge {active: ($option.value == $selected)} }
    }
    _ if $category in $hdr_value_categories => { hdr-options $category $selected }
    _ => { [] }
  }
  | each {|option|
    lib apply-row $"monitor:value:($category):($option.value)" $option.label "value" {
      output: $output_name
      category: $category
      value: $option.value
    } ($option.active? | default false)
  }
}

def run-action [output_name: string, category: string, value: string] {
  match $category {
    "mode" => {
      niri msg output $output_name mode $value | ignore
    }
    "scale" => {
      niri msg output $output_name scale $value | ignore
    }
    "vrr" => {
      if $value == "on-demand" {
        niri msg output $output_name vrr on --on-demand | ignore
      } else {
        niri msg output $output_name vrr $value | ignore
      }
    }
    "brightness" => {
      ^sh -c '
        ddcutil setvcp 10 "$1" >/dev/null 2>&1 &
      ' sh $value | ignore
    }
    "hdr-mode" => {
      niri msg output $output_name hdr-mode $value | ignore
    }
    "hdr-reference-luminance" => {
      niri msg output $output_name hdr-reference-luminance $value | ignore
    }
    "sdr-brightness" => {
      niri msg output $output_name sdr-brightness $value | ignore
    }
    "sdr-saturation" => {
      niri msg output $output_name sdr-saturation $value | ignore
    }
    _ => { }
  }
}

def outputs [] {
  try {
    niri msg --json outputs
    | from json
    | transpose key output
    | each {|item|
      let output = $item.output
      let name = $output.name? | default $item.key
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
  } catch { [] }
}

def output-by-name [output_name: string] {
  outputs | where name == $output_name | get -o 0 | default {}
}

def current-value-label [output_name: string, category: string] {
  let output = output-by-name $output_name
  let value = current-value $output $category

  match $category {
    "mode" => {
      let index = $output.current_mode? | default null
      let mode = if $index == null { null } else {
        $output.modes | get -o $index | default null
      }
      if $mode == null {
        ""
      } else {
        let hz = $mode.refresh_rate / 1000.0
        $"($mode.width)x($mode.height) @ ($hz)Hz"
      }
    }
    "scale" => {
      $output.logical.scale? | default "" | into string | str replace --regex '\.0$' ""
    }
    "hdr-mode" => { $value }
    "hdr-reference-luminance" | "sdr-brightness" | "sdr-saturation" => {
      if ($value | is-empty) { "" } else { value-label $category $value }
    }
    _ => { "" }
  }
}

def current-value [output: record, category: string] {
  match $category {
    "hdr-mode" => {
      $output.hdr_mode? | default "" | into string | str downcase
    }
    "hdr-reference-luminance" => {
      $output.hdr_reference_luminance? | default "" | clean-number
    }
    "sdr-brightness" => {
      $output.sdr_brightness? | default "" | clean-number
    }
    "sdr-saturation" => {
      $output.sdr_saturation? | default "" | clean-number
    }
    _ => { "" }
  }
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
  let current = if ($output.vrr_enabled? | default false) { "on" } else { "off" }
  [
    {value: "on", label: "On"}
    {value: "on-demand", label: "On demand"}
    {value: "off", label: "Off"}
  ]
  | each {|vrr| $vrr | merge {active: ($vrr.value == $current)} }
}

def hdr-options [category: string, selected: string] {
  match $category {
    "hdr-reference-luminance" => {
      [
        "203"
        "300"
        "400"
        "500"
        "600"
        "800"
        "1000"
      ]
    }
    "sdr-brightness" => { ["0.9" "1" "1.1" "1.2" "1.3"] }
    "sdr-saturation" => {
      [
        "1"
        "1.1"
        "1.2"
        "1.3"
        "1.4"
        "1.5"
      ]
    }
    _ => { [] }
  }
  | each {|value| {value: $value, label: (value-label $category $value), active: ($value == $selected)} }
}

def value-label [category: string, value: string] {
  match $category {
    "brightness" => { $"($value)%" }
    "hdr-reference-luminance" => { $"($value) nits" }
    "sdr-brightness" | "sdr-saturation" => { $"($value)x" }
    _ => { $value }
  }
}

def clean-number [] {
  $in | into string | str replace --regex '\.0$' ""
}
