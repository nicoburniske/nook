use ./lib.nu [action-row module-row render-menu]

const prefix = "sunset"

const actions = {
  apply: $"($prefix):apply"
}

export def entry [] {
  {
    prefix: $prefix
    root-row: (module-row "sunset" $prefix)
    render: {|| render-menu "cmd > sunset" (list-presets) }
    handle: {|action| handle $action }
  }
}

def handle [action: record] {
  if $action.kind == $actions.apply {
    apply $action.value
    render-menu "cmd > sunset" (list-presets)
  }
}

def list-presets [] {
  [
    {value: "off", label: "Off"}
    {value: "5000", label: "Light - 5000K"}
    {value: "4500", label: "Medium - 4500K"}
    {value: "4000", label: "Warm - 4000K"}
    {value: "3500", label: "Deep - 3500K"}
  ]
  | each {|preset|
      action-row $preset.label $actions.apply {value: $preset.value}
    }
}

def apply [value: string] {
  ^pkill -x wlsunset err> /dev/null | complete | ignore

  if $value == "off" {
    return
  }

  let high = ($value | into int) + 1

  ^sh -c '
    wlsunset -T "$2" -t "$1" -S 23:59 -s 00:00 >/dev/null 2>&1 &
  ' sh $value $high | ignore
}
