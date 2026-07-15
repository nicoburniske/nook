use ./lib.nu

const prefix = "audio"

export def entry [] {
  {
    prefix: $prefix
    root-row: (lib page-row $prefix "audio" $prefix)
    header: {|state| header $state }
    rows: {|state| rows $state }
    apply: {|state, data| apply $state $data }
  }
}

def header [state: record] {
  match $state.page {
    "audio" => { {title: "cmd > audio", current: ""} }
    "audio:volume" => {
      {
        title: "cmd > audio > volume"
        current: (current-volume-label)
      }
    }
    "audio:output" => { {title: "cmd > audio > output", current: ""} }
    "audio:profile" => { {title: "cmd > audio > profile", current: ""} }
    _ => {
      let page = $state.page | str replace "audio:" ""
      {
        title: $"cmd > audio > ($page)"
        current: ""
      }
    }
  }
}

def rows [state: record] {
  match $state.page {
    "audio" => {
      [
        (lib page-row "audio:profile" "profile" "audio:profile")
        (lib page-row "audio:output" "output" "audio:output")
        (lib page-row "audio:volume" "volume" "audio:volume")
        (lib apply-row "audio:restart" "restart audio services" "restart")
      ]
    }
    "audio:profile" => {
      let card = active-output-card
      if $card == null {
        [
          (lib row "audio:profile:none" "no active output card found")
        ]
      } else {
        let active = $card.active_profile? | default ""
        $card.profiles
        | transpose name profile
        | where {|item| $item.profile.available? | default true }
        | where {|item| ($item.profile.sinks? | default 0) > 0 }
        | sort-by --reverse {|item| $item.profile.priority? | default 0 }
        | each {|item|
          let label = $item.profile.description | clean-field $item.name
          lib apply-row $"audio:profile:($item.name)" $label "profile" {
            card: $card.name
            profile: $item.name
          } ($item.name == $active)
        }
      }
    }
    "audio:output" => {
      let active = try {
        ^pactl get-default-sink err> /dev/null | str trim
      } catch { "" }
      let sinks = try {
        ^pw-dump
        | from json
        | where type == "PipeWire:Interface:Node"
        | each {|node|
          let props = $node.info.props

          if (($props | get -o "media.class" | default "") == "Audio/Sink") {
            {
              name: ($props | get "node.name")
              description: ($props | get -o "node.description" | default "")
            }
          }
        }
        | compact
      } catch { [] }

      if ($sinks | is-empty) {
        [
          (lib row "audio:output:none" "no audio outputs found")
        ]
      } else {
        $sinks
        | sort-by description name
        | each {|sink|
          let label = $sink.description | clean-field $sink.name
          lib apply-row $"audio:output:($sink.name)" $label "output" {sink: $sink.name} ($sink.name == $active)
        }
      }
    }
    "audio:volume" => {
      let active = current-volume
      ["0" "25" "50" "75" "100"]
      | each {|volume|
        lib apply-row $"audio:volume:($volume)" $"($volume)%" "volume" {volume: $volume} ($volume == $active)
      }
    }
    _ => { [] }
  }
}

def apply [state: record, data: record] {
  run-action $data
  $state
}

def run-action [data: record] {
  match ($data.kind? | default "") {
    "profile" => { ^pactl set-card-profile $data.card $data.profile }
    "output" => {
      ^pactl set-default-sink $data.sink
      try {
        pactl-json sink-inputs
        | each {|input| ^pactl move-sink-input $input.index $data.sink }
        | ignore
      } catch { }
    }
    "volume" => {
      ^pactl set-sink-mute @DEFAULT_SINK@ 0
      ^pactl set-sink-volume @DEFAULT_SINK@ $"($data.volume)%"
    }
    "restart" => {
      ^systemctl --user restart pipewire pipewire-pulse wireplumber
      ^systemctl --user restart noctalia
    }
    _ => { }
  }
}

def clean-field [fallback: string] {
  let value = $in | default ""

  if ($value | is-empty) {
    $fallback
  } else {
    $value
    | str replace --all "\t" " "
    | str replace --all "\n" " "
  }
}

def current-volume [] {
  try {
    ^pactl get-sink-volume @DEFAULT_SINK@ err> /dev/null
    | parse --regex '\s(?P<volume>\d+)%'
    | get -o volume.0
    | default ""
  } catch { "" }
}

def current-volume-label [] {
  let volume = current-volume
  if ($volume | is-empty) { "" } else { $"($volume)%" }
}

def active-output-card [] {
  let default_sink = try {
    ^pactl get-default-sink err> /dev/null | str trim
  } catch { "" }

  let sink = (
    pactl-json sinks
    | where name == $default_sink
    | get -o 0
    | default null
  )

  let device_id = $sink.properties | get -o "device.id" | default ""

  pactl-json cards
  | where {|card| (($card.properties | get -o "object.id" | default "") | into string) == ($device_id | into string) }
  | get -o 0
  | default null
}

def pactl-json [kind: string] {
  ^pactl -f json list $kind err> /dev/null | from json
}
