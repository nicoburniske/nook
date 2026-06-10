export def main [] {
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
            name: $name
            directory: $row.directory
            sort_key: ($name | str downcase)
          }
        }
      | where {|row| $row.directory != "System Profile" and $row.name != "Your Helium" }
      | sort-by sort_key
      | select name directory
  )

  if ($profiles | is-empty) {
    print --stderr "No Helium profiles found."
    exit 1
  }

  let selection = (
    $profiles
      | get name
      | str join "\n"
      | choose "helium> "
  )
  let directory = (($profiles | where name == $selection | get -o 0.directory) | default "")

  if ($directory | is-empty) {
    exit 0
  }

  helium $"--user-data-dir=($data_dir)" $"--profile-directory=($directory)"
}

def choose [prompt: string] {
  let result = (
    do {
      $in | fuzzel --dmenu --prompt $prompt
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
