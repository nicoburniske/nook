const title_id = "CUSA00900"
const save_slot = "SPRJ0005"
const checkpoint_prefix = "bloodborne-SPRJ0005"

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

def save-actions [] {
  [
    {value: "save", description: "copy the current live save with a required label"}
    {value: "delete", description: "delete a save by numeric index"}
    {value: "list", description: "show saves newest to oldest"}
    {value: "restore", description: "restore a save by numeric index"}
    {value: "paths", description: "print live save and save storage paths"}
  ]
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

def save-indexes [] {
  checkpoint-records
    | each {|checkpoint|
        {
          value: ($checkpoint.index | into string)
          description: $checkpoint.name
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

def warn-if-shadps4-running [] {
  let emulator_names = [
    "shadps4"
    "shadps4-qt"
    "shadps4-qtlauncher"
  ]

  let matches = (
    ps
      | where {|process|
          let name = ($process.name | str downcase)
          $name in $emulator_names
        }
  )

  if ($matches | length) > 0 {
    print "warning: shadPS4 appears to be running; save files may be changing"
  }
}

def ensure-live-save [] {
  let save = active-save

  if not ($save | path exists) {
    error make {
      msg: $"active save does not exist: ($save)"
    }
  }
}

def resolve-index [target] {
  if ($target | is-empty) {
    error make {
      msg: "target must be a numeric index from `bbsave list`"
    }
  }

  if not ($target =~ '^[0-9]+$') {
    error make {
      msg: $"target must be a numeric index from `bbsave list`: ($target)"
    }
  }

  let checkpoints = checkpoint-records
  let index = ($target | into int)
  let selected = ($checkpoints | where index == $index)

  if ($selected | is-empty) {
    error make {
      msg: $"save index not found: ($target)"
    }
  }

  $selected | first
}

def print-paths [] {
  {
    active_save: (active-save)
    checkpoints: (checkpoints-root)
  }
}

def list-checkpoints [] {
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

def create-checkpoint [label] {
  warn-if-shadps4-running
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

def confirm-restore [checkpoint: record] {
  print $"restore save ($checkpoint.index): ($checkpoint.name)"
  print $"from: ($checkpoint.path)"
  print $"to:   (active-save)"

  confirm
}

def confirm-delete [checkpoint: record] {
  print $"delete save ($checkpoint.index): ($checkpoint.name)"
  print $"path: ($checkpoint.path)"

  confirm
}

def restore-checkpoint [target] {
  warn-if-shadps4-running
  ensure-live-save

  let checkpoint = resolve-index $target

  if not (confirm-restore $checkpoint) {
    print "restore cancelled"
    return
  }

  rm --recursive (active-save)
  cp --recursive $checkpoint.path (active-save)

  print $"restored save ($checkpoint.index): ($checkpoint.name)"
}

def delete-checkpoint [target] {
  let checkpoint = resolve-index $target

  if not (confirm-delete $checkpoint) {
    print "delete cancelled"
    return
  }

  rm --recursive $checkpoint.path
  print $"deleted save ($checkpoint.index): ($checkpoint.name)"
}

export def main [
  action: string@save-actions
  target?: string@save-indexes
] {
  match $action {
    "save" => { create-checkpoint $target }
    "delete" => { delete-checkpoint $target }
    "list" => { list-checkpoints }
    "paths" => { print-paths }
    "restore" => { restore-checkpoint $target }
    _ => {
      error make {
        msg: $"unknown action: ($action)"
      }
    }
  }
}
