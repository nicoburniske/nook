use ./audio.nu
use ./helium.nu
use ./lib.nu [rofi-header rofi-row]
use ./monitor.nu
use ./sunset.nu
use ./theme.nu
use ./window.nu

export def main [selection?: string] {
  if "ROFI_RETV" not-in ($env | columns) {
    launch-rofi
    return
  }

  let retv = $env.ROFI_RETV | into int
  if $retv == 0 {
    render-root
    return
  }

  if $retv == 10 {
    handle-action (back-action)
    return
  }

  let action = (
    $env.ROFI_INFO?
    | default ""
    | parse-action
  )

  if $action == null {
    render-root
    return
  }

  handle-action $action
}

def launch-rofi [] {
  let config = [$env.HOME ".config" "rofi" "niri-cmd.rasi"] | path join
  ^rofi -config $config -show scripts -modes $"scripts:($env.PROCESS_PATH)" -matching fuzzy -sorting-method fzf -i
}

def handle-action [action: record] {
  let kind = $action.kind? | default ""

  if $kind == "root" {
    render-root
    return
  }

  if $kind == "exit" {
    return
  }

  if $kind == "module" {
    let module = modules | where prefix == $action.module | get 0
    do $module.render
    return
  }

  let prefix = (
        $kind
        | split row ":"
        | get -o 0
        | default ""
    )
  let module = (
        modules
        | where prefix == $prefix
        | get -o 0
        | default null
    )

  if $module == null {
    render-root
  } else {
    do $module.handle $action
  }
}

def render-root [] {
  rofi-header "cmd" {back: {kind: "exit"}}
  modules | each { rofi-row $in.root-row.text $in.root-row.action } | ignore
}

def back-action [] {
  $env.ROFI_DATA?
  | default ""
  | parse-action
  | default {}
  | get -o back
  | default {kind: "root"}
}

def modules [] {
  [
    (window entry)
    (theme entry)
    (helium entry)
    (monitor entry)
    (audio entry)
    (sunset entry)
  ]
}

def parse-action [] {
  let raw = $in | str trim
  if ($raw | is-empty) {
    null
  } else {
    try {
      $raw | from json
    } catch {
      null
    }
  }
}
