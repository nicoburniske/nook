use ./lib.nu

export def entry [] {
  {
    prefix: "mirror"
    root-row: (lib page-row "mirror" "mirror" "mirror")
    header: {|_state| {title: "cmd > mirror", current: ""} }
    rows: {|_state| rows }
    apply: {|state, data| apply $state $data }
  }
}

def rows [] {
  let active = (systemctl --user is-active niri-mirror.service | complete).exit_code == 0
  let outputs = niri msg --json outputs | from json | values | where logical != null | sort-by name

  [
    (lib apply-row "mirror:off" "Disable mirroring" "off" {} (not $active))
  ]
  | append ($outputs | each {|source|
    $outputs | where name != $source.name | each {|target|
      lib apply-row $"mirror:($source.name):($target.name)" $"($source.name) → ($target.name)" "on" {
        source: $source.name
        target: $target.name
      }
    }
  } | flatten)
}

export def apply [state: record, data: record] {
  systemctl --user stop niri-mirror.service | complete | ignore

  if $data.kind == "on" {
    let executable = which wl-mirror | get 0.path
    let origin = niri msg --json focused-output | from json | get name
    let follow = '
            let pid = $env.MAINPID | into int
            mut id: any = null
            for line in (niri msg --json event-stream | lines) {
                let event = $line | from json
                let windows = $event.WindowsChanged?.windows? | default []
                    | append ($event.WindowOpenedOrChanged?.window? | default [])
                mut focused = false
                for window in ($windows | where pid == $pid) {
                    $id = $window.id
                    $focused = $window.is_focused
                }
                if $focused or ($id != null and $event.WindowFocusChanged?.id? == $id) {
                    niri msg action focus-monitor $env.MIRROR_ORIGIN | ignore
                    exit 0
                }
            }
        '
    systemd-run ...[
      "--user"
      "--collect"
      "--unit=niri-mirror"
      "--property=Type=exec"
      $"--property=ExecStartPost=($nu.current-exe) -c '($follow)'"
      $"--setenv=MIRROR_ORIGIN=($origin)"
      $"--setenv=PATH=($env.PATH | str join ':')"
      $"--setenv=WAYLAND_DISPLAY=($env.WAYLAND_DISPLAY)"
      $"--setenv=XDG_RUNTIME_DIR=($env.XDG_RUNTIME_DIR)"
      $executable
      "--fullscreen-output" $data.target
      $data.source
    ] | ignore
  }

  $state
}
