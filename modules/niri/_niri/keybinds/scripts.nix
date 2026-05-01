{
  inputs,
  pkgs,
}: {
  themeSwitch = import (inputs.self + "/common/theme-switch.nix") {inherit pkgs;};

  heliumProfile = pkgs.writeNuScriptBin "helium-profile" ''
    let helium = "${pkgs.helium}/bin/helium"
    let fuzzel = "${pkgs.fuzzel}/bin/fuzzel"
    let data_dir = ([$env.HOME ".config" "net.imput.helium"] | path join)
    let local_state = ([$data_dir "Local State"] | path join)

    if not ($local_state | path exists) {
      print --stderr "Helium profile data not found."
      exit 1
    }

    let state = (open --raw $local_state | from json)
    let info_cache = (($state | get -o profile.info_cache) | default {})

    let profiles = (
      $info_cache
      | transpose directory data
      | each {|row|
          let name = ($row.data.name? | default $row.directory)
          {
            name: $name,
            directory: $row.directory,
            sort_key: ($name | str downcase),
          }
        }
      | where {|row| $row.directory != "System Profile" and $row.name != "Your Helium" }
      | sort-by sort_key
      | each {|row| {name: $row.name, directory: $row.directory} }
    )

    if (($profiles | length) == 0) {
      print --stderr "No Helium profiles found."
      exit 1
    }

    let menu = ($profiles | get name | str join "\n")
    let fuzzel_result = (do { $menu | ^$fuzzel --dmenu --prompt "helium> " } | complete)

    if $fuzzel_result.exit_code != 0 {
      exit 0
    }

    let selection = ($fuzzel_result.stdout | str trim)
    if $selection == "" {
      exit 0
    }

    let directory = (($profiles | where name == $selection | get -o 0.directory) | default "")
    if $directory == "" {
      exit 0
    }

    ^$helium $"--user-data-dir=($data_dir)" $"--profile-directory=($directory)"
  '';

  windowSwitch = pkgs.writeNuScriptBin "niri-window-switch" ''
    let windows = (
      niri msg --json windows
      | from json
      | each {|window|
          let title = (
            if (($window.title? | default "") == "") { "(untitled)" } else { $window.title }
            | str replace --all "\t" " "
            | str replace --all "\n" " "
          )
          let app_id = (
            if (($window.app_id? | default "") == "") { "unknown" } else { $window.app_id }
            | str replace --all "\t" " "
            | str replace --all "\n" " "
          )
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
            id: $window.id,
            row: ([$window.id $"($workspace) - ($app) - ($detail)"] | str join "\t"),
            sort_key: $"($workspace)-($app)-($detail)",
          }
        }
      | sort-by sort_key
    )

    if (($windows | length) == 0) {
      exit 0
    }

    let menu = ($windows | get row | str join "\n")
    let result = (
      do {
        $menu | fuzzel --dmenu --prompt "window> " --match-mode exact --with-nth 2 --accept-nth 1 --match-nth 2 --only-match
      } | complete
    )

    if $result.exit_code != 0 {
      exit 0
    }

    let id = ($result.stdout | str trim)
    if $id == "" {
      exit 0
    }

    niri msg action focus-window --id $id | ignore
  '';
}
