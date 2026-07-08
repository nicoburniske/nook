use ./lib.nu

const prefix = "helium"

export def entry [] {
  {
    prefix: $prefix
    root-row: (lib page-row $prefix "helium" $prefix)
    header: {|_state| {title: "cmd > helium", current: ""} }
    rows: {|_state| rows }
    apply: {|state, data| apply $state $data }
  }
}

def rows [] {
  let local_state = [
    (data-dir)
    "Local State"
  ] | path join
  if not ($local_state | path exists) {
    return [
      (lib row "helium:none" "no helium profiles found")
    ]
  }

  let state = open --raw $local_state | from json
  let info_cache = ($state | get -o profile.info_cache) | default {}

  $info_cache
  | transpose directory data
  | each {|profile|
    let name = $profile.data.name? | default $profile.directory
    {
      name: $name
      directory: $profile.directory
      sort_key: ($name | str downcase)
    }
  }
  | where {|profile| $profile.directory != "System Profile" and $profile.name != "Your Helium" }
  | sort-by sort_key
  | each {|profile|
    lib apply-row $"helium:($profile.directory)" $profile.name "profile" {directory: $profile.directory} false $profile.directory
  }
}

def apply [state: record, data: record] {
  if ($data.kind? | default "") == "profile" and ($data.directory? | default "") != "" {
    let dir = data-dir
    ^sh -c 'setsid -f "$@" </dev/null >/dev/null 2>&1' sh helium $"--user-data-dir=($dir)" $"--profile-directory=($data.directory)"
  }
  $state
}

def data-dir [] {
  [$env.HOME ".config" "net.imput.helium"] | path join
}
