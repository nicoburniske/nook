const title_id = "CUSA00900"
const save_slot = "SPRJ0005"
const checkpoint_prefix = "bloodborne-SPRJ0005"

# show help
export def main [] {
  help main
}

# copy the current live save with a label
export def "main save" [
  label: string
] {
  ensure-live-save

  let root = checkpoints-root
  mkdir $root

  if ($label | is-empty) {
    error make {msg: "save requires a label"}
  }

  let normalized = (safe-label $label)

  if ($normalized | is-empty) {
    error make {
      msg: $"save label must include at least one letter or number: ($label)"
    }
  }

  let suffix = $"-($normalized)"
  let destination = $root | path join $"($checkpoint_prefix)-(now-stamp)($suffix)"

  cp --recursive (active-save) $destination
  print $"save created: ($destination)"
}

# show saves newest to oldest
export def "main list" [] {
  let checkpoints = checkpoint-records

  if ($checkpoints | is-empty) {
    print $"no saves found in (checkpoints-root)"
    return
  }

  $checkpoints
    | insert timestamp {|checkpoint| $"(checkpoint-time $checkpoint.name) ($checkpoint.modified)" }
    | insert label {|checkpoint| save-label $checkpoint.name }
    | select index timestamp label name path
}

# restore a save by index from `bbsave list`
export def "main restore" [
  index: int
] {
  ensure-live-save

  let checkpoint = resolve-index $index

  rm --recursive (active-save)
  cp --recursive $checkpoint.path (active-save)

  print $"restored save ($checkpoint.index): ($checkpoint.name)"
}

# delete saves by index or inclusive ranges like `2..5`
export def "main delete" [
  ...targets: string
] {
  let checkpoints = resolve-indices $targets

  if not (confirm-delete $checkpoints) {
    print "delete cancelled"
    return
  }

  for checkpoint in $checkpoints {
    rm --recursive $checkpoint.path
    print $"deleted save ($checkpoint.index): ($checkpoint.name)"
  }
}

# print live save and checkpoint storage paths
export def "main paths" [] {
  {
    active_save: (active-save)
    checkpoints: (checkpoints-root)
  }
}


def active-save [] {
  $env.HOME | path join ".local/share/shadPS4/savedata/1" $title_id $save_slot
}

def checkpoints-root [] {
  $env.HOME | path join ".local/share/shadPS4/checkpoints"
}

def now-stamp [] {
  date now | format date "%Y%m%d-%H%M%S"
}

def safe-label [label: string] {
  $label
    | str downcase
    | str replace --all --regex '[^a-z0-9._-]+' '-'
    | str trim --char '-'
}

def checkpoint-records [] {
  let root = checkpoints-root

  if not ($root | path exists) {
    return []
  }

  ls $root
    | where type == dir
    | where {|entry| ($entry.name | path basename) | str starts-with $"($checkpoint_prefix)-" }
    | sort-by modified --reverse
    | enumerate
    | each {|row|
        {
          index: $row.index
          name: ($row.item.name | path basename)
          path: $row.item.name
          modified: $row.item.modified
        }
      }
}

def checkpoint-time [name: string] {
  let raw = (
    $name
      | str replace $"($checkpoint_prefix)-" ""
      | str substring 0..14
  )

  try {
    $raw
      | into datetime --format "%Y%m%d-%H%M%S"
      | format date "%Y-%m-%d %H:%M:%S"
  } catch {
    ""
  }
}

def save-label [name: string] {
  $name | str replace --regex '^bloodborne-SPRJ0005-[0-9]{8}-[0-9]{6}-?' ''
}

def ensure-live-save [] {
  let save = active-save

  if not ($save | path exists) {
    error make {
      msg: $"active save does not exist: ($save)"
    }
  }
}

def resolve-index [index: int] {
  let checkpoints = checkpoint-records
  let selected = ($checkpoints | where index == $index)

  if ($selected | is-empty) {
    error make {
      msg: $"save index not found: ($index)"
    }
  }

  $selected | first
}

def expand-index-target [target] {
  let parts = $target | split row ".."

  if (($parts | length) == 1) {
    return [($parts | first | into int)]
  }

  let start = $parts | get 0 | into int
  let end = $parts | get 1 | into int
  $start..$end | each {|index| $index }
}

def resolve-indices [targets: list<string>] {
  $targets
    | each {|target| expand-index-target $target }
    | flatten
    | uniq
    | each {|index| resolve-index $index }
}

def confirm [] {
  let answer = (
    try {
      input "Continue? [y/N] "
    } catch {
      ""
    }
    | str downcase
    | str trim
  )
  $answer in ["y", "yes"]
}

def confirm-delete [checkpoints: list<record>] {
  if (($checkpoints | length) == 1) {
    let checkpoint = $checkpoints | first
    print $"delete save ($checkpoint.index): ($checkpoint.name)"
    print $"path: ($checkpoint.path)"
  } else {
    print $"delete ($checkpoints | length) saves:"

    for checkpoint in $checkpoints {
      print $"  ($checkpoint.index): ($checkpoint.name)"
    }
  }

  confirm
}
