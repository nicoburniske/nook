use ./lib.nu [action-row active-label clean-field module-row render-menu]

const prefix = "audio"

const actions = {
  profiles: $"($prefix):profiles"
  outputs: $"($prefix):outputs"
  profile: $"($prefix):profile"
  output: $"($prefix):output"
}

export def entry [] {
  {
    prefix: $prefix
    root-row: (module-row "audio" $prefix)
    render: {|| render-menu "cmd > audio" [
      (action-row "profile" $actions.profiles)
      (action-row "output" $actions.outputs)
    ] }
    handle: {|action| handle $action }
  }
}

def handle [action: record] {
  if $action.kind == $actions.profiles {
    render-menu "cmd > audio > profile" (list-profiles) {kind: "module", module: $prefix}
  } else if $action.kind == $actions.outputs {
    let active = (
      try {
        ^pactl get-default-sink err> /dev/null | str trim
      } catch { "" }
    )
    let sinks = (
      try {
        pactl-json sinks
      } catch { [] }
    )

    render-menu "cmd > audio > output" (
      if ($sinks | is-empty) {
        [(action-row "no audio outputs found" "root")]
      } else {
        $sinks
        | sort-by description name
        | each {|sink|
            let label = (
              $sink.description?
              | default ($sink.properties | get -o "device.description")
              | clean-field $sink.name
            )

            action-row (active-label $label ($sink.name == $active)) $actions.output {sink: $sink.name}
          }
      }
    ) {kind: "module", module: $prefix}
  } else if $action.kind == $actions.profile {
    apply-profile $action.card $action.profile
    handle {kind: $actions.profiles}
  } else if $action.kind == $actions.output {
    ^pactl set-default-sink $action.sink
    try {
      pactl-json sink-inputs
      | each {|input| ^pactl move-sink-input $input.index $action.sink }
      | ignore
    } catch { }
    handle {kind: $actions.outputs}
  }
}

def list-profiles [] {
  let card = active-output-card

  if $card == null {
    return [
      (action-row "no active output card found" "root")
    ]
  }

  let active = $card.active_profile? | default ""

  $card.profiles
  | transpose name profile
  | where {|row| $row.profile.available? | default true }
  | where {|row| ($row.profile.sinks? | default 0) > 0 }
  | sort-by --reverse {|row| $row.profile.priority? | default 0 }
  | each {|row|
        let label = $row.profile.description | clean-field $row.name

        action-row (active-label $label ($row.name == $active)) $actions.profile {
          card: $card.name
          profile: $row.name
        }
      }
}

def apply-profile [card: string, profile: string] {
  ^pactl set-card-profile $card $profile
}

def active-output-card [] {
  let default_sink = (
        try {
            ^pactl get-default-sink err> /dev/null | str trim
        } catch { "" }
    )

  if ($default_sink | is-empty) {
    return null
  }

  let sink = (
    pactl-json sinks
    | where name == $default_sink
    | get -o 0
    | default null
  )

  if $sink == null {
    return null
  }

  let device_id = $sink.properties | get -o "device.id" | default ""

  if ($device_id | is-empty) {
    return null
  }

  pactl-json cards
  | where {|card| (($card.properties | get -o "object.id" | default "") | into string) == ($device_id | into string) }
  | get -o 0
  | default null
}

def pactl-json [kind: string] {
  ^pactl -f json list $kind err> /dev/null | from json
}
