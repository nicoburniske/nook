export def main [] {
  let windows = (
    niri msg --json windows
      | from json
      | each {|window|
          let title = ($window.title? | default "" | clean-field "(untitled)")
          let app_id = ($window.app_id? | default "" | clean-field "unknown")
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
          let workspace = ($window.workspace_id? | default "?")

          {
            id: $window.id
            row: ([$window.id $"($workspace) - ($app) - ($detail)"] | str join "\t")
            sort_key: $"($workspace)-($app)-($detail)"
          }
        }
      | sort-by sort_key
  )

  if ($windows | is-empty) {
    exit 0
  }

  let id = (
    $windows
      | get row
      | str join "\n"
      | choose "window> "
  )

  niri msg action focus-window --id $id | ignore
}

def clean-field [fallback: string] {
  let value = ($in | default "")

  if ($value | is-empty) {
    $fallback
  } else {
    $value
      | str replace --all "\t" " "
      | str replace --all "\n" " "
  }
}

def choose [prompt: string] {
  let result = (
    do {
      $in | fuzzel --dmenu --prompt $prompt --match-mode exact --with-nth 2 --accept-nth 1 --match-nth 2 --only-match
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
