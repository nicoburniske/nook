use ./lib.nu [action-row clean-field module-row render-menu]

const prefix = "window"

const actions = {
  focus: $"($prefix):focus"
}

export def entry [] {
  {
    prefix: $prefix
    root-row: (module-row "window" $prefix)
    render: {|| render-menu "cmd > window" (list-windows) }
    handle: {|action| handle $action }
  }
}

def handle [action: record] {
  if $action.kind == $actions.focus {
    focus $action.id
  }
}

def list-windows [] {
  niri msg --json windows
  | from json
  | each {|window|
        let title = $window.title? | default "" | clean-field "(untitled)"
        let app_id = $window.app_id? | default "" | clean-field "unknown"
        let app = (
          if ($title | str ends-with " - YouTube - Helium") { "youtube" }
          else if ($app_id | str starts-with "chrome-open.spotify.com") { "spotify" }
          else { $app_id }
        )
        let detail = (
          if ($title | str ends-with " - YouTube - Helium") { $title | str replace --regex " - YouTube - Helium$" "" }
          else if ($title | str ends-with " - Helium") { $title | str replace --regex " - Helium$" "" }
          else { $title }
        )
        let workspace = $window.workspace_id? | default "?"

        action-row $"($workspace) - ($app) - ($detail)" $actions.focus {id: $window.id}
          | merge {sort_key: $"($workspace)-($app)-($detail)"}
      }
  | sort-by sort_key
  | reject sort_key
}

def focus [id] {
  niri msg action focus-window --id $id | ignore
}
