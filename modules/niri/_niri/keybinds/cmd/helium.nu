use ./lib.nu [action-row module-row render-menu]

const prefix = "helium"

const actions = {
  profile: $"($prefix):profile"
}

export def entry [] {
  {
    prefix: $prefix
    root-row: (module-row "helium" $prefix)
    render: {|| render-menu "cmd > helium" (list-profiles) }
    handle: {|action| handle $action }
  }
}

def handle [action: record] {
  if $action.kind == $actions.profile {
    run-profile $action.directory
  }
}

def list-profiles [] {
  let data_dir = data-dir
  let local_state = [$data_dir "Local State"] | path join

  if not ($local_state | path exists) {
    return []
  }

  let state = open --raw $local_state | from json
  let info_cache = ($state | get -o profile.info_cache) | default {}
  let profiles = (
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
      | select name directory
      | each {|profile|
          action-row $profile.name $actions.profile {directory: $profile.directory}
        }
  )

  $profiles
}

def run-profile [directory: string] {
  if ($directory | is-empty) {
    exit 0
  }
  let data_dir = data-dir
  ^sh -c '"$@" >/dev/null 2>&1 &' sh helium $"--user-data-dir=($data_dir)" $"--profile-directory=($directory)"
}

def data-dir [] {
  [$env.HOME ".config" "net.imput.helium"] | path join
}
