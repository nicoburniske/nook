export def active-label [label: string, active: bool] {
  if $active {
    $"* ($label)"
  } else {
    $"  ($label)"
  }
}

export def clean-field [fallback: string] {
  let value = $in | default ""

  if ($value | is-empty) {
    $fallback
  } else {
    $value
    | str replace --all "\t" " "
    | str replace --all "\n" " "
  }
}

export def rofi-header [prompt: string, data?: record] {
  print $"(char nul)prompt(char unit_separator)($prompt)"
  print $"(char nul)no-custom(char unit_separator)true"

  if $data != null {
    print $"(char nul)use-hot-keys(char unit_separator)true"
    print $"(char nul)data(char unit_separator)($data | to json --raw)"
  }
}

export def rofi-row [text: string, action: record] {
  let encoded = $action | to json --raw
  print $"($text)(char nul)info(char unit_separator)($encoded)"
}

export def action-row [text: string, kind: string, payload: record = {}] {
  {
    text: $text
    action: ({kind: $kind} | merge $payload)
  }
}

export def module-row [text: string, module: string] {
  action-row $text "module" {module: $module}
}

export def render-menu [prompt: string, rows: list<any>, back?: record] {
  let back_action = $back | default {kind: "root"}
  rofi-header $prompt {back: $back_action}
  $rows | each { rofi-row $in.text $in.action } | ignore
}
