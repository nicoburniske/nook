{pkgs}:
pkgs.writeNuScriptBin "chromium-profile" ''
  let chromium = "${pkgs.ungoogled-chromium}/bin/chromium"
  let fuzzel = "${pkgs.fuzzel}/bin/fuzzel"
  let data_dir = ([$env.HOME ".config" "chromium"] | path join)
  let local_state = ([$data_dir "Local State"] | path join)

  if not ($local_state | path exists) {
    print --stderr "Chromium profile data not found."
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
    | where {|row| $row.directory != "System Profile" and $row.name != "Your Chromium" }
    | sort-by sort_key
    | each {|row| {name: $row.name, directory: $row.directory} }
  )

  if (($profiles | length) == 0) {
    print --stderr "No Chromium profiles found."
    exit 1
  }

  let menu = ($profiles | get name | str join "\n")
  let fuzzel_result = (do { $menu | ^$fuzzel --dmenu --prompt "chrome> " } | complete)

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

  ^$chromium $"--user-data-dir=($data_dir)" $"--profile-directory=($directory)"
''
