use ./lib.nu

const prefix = "sunset"

export def entry [] {
  {
    prefix: $prefix
    root-row: (lib page-row $prefix "sunset" $prefix)
    header: {|_state| {title: "cmd > sunset", current: ""} }
    rows: {|_state| rows }
    apply: {|state, data| apply $state $data }
  }
}

def rows [] {
  [
    {value: "off", label: "Off"}
    {value: "5000", label: "Light - 5000K"}
    {value: "4500", label: "Medium - 4500K"}
    {value: "4000", label: "Warm - 4000K"}
    {value: "3500", label: "Deep - 3500K"}
  ]
  | each {|preset|
    lib apply-row $"sunset:($preset.value)" $preset.label "preset" {value: $preset.value}
  }
}

def apply [state: record, data: record] {
  if ($data.kind? | default "") == "preset" {
    apply-preset $data.value
  }
  $state
}

def apply-preset [value: string] {
  ^pkill -x wlsunset err> /dev/null | complete | ignore

  if $value == "off" {
    return
  }

  let high = ($value | into int) + 1
  ^sh -c '
    nohup wlsunset -T "$2" -t "$1" -S 23:59 -s 00:00 </dev/null >/dev/null 2>&1 &
  ' sh $value $high | ignore
}
