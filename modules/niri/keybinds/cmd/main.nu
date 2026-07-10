use ./audio.nu
use ./helium.nu
use ./lib.nu
use ./monitor.nu
use ./search.nu
use ./sunset.nu
use ./theme.nu

export def main [] {
  mut state = initial-state
  mut raw_rows = raw-rows $state
  mut current_header = header $state
  mut search_state = search initial

  print -n (ansi cursor_off)
  try {
    loop {
      if $search_state.active {
        let view = search view $search_state
        draw $view.header $view.state $view.rows
      } else {
        draw $current_header $state $raw_rows
      }

      let event = input listen --types [key resize]
      if $event.type == "resize" {
        continue
      }

      let search_result = search handle-event $search_state $event {|| build-search-index }
      $search_state = $search_result.search

      if $search_result.handled {
        if $search_result.jump != null {
          $state = $search_result.jump.state
          $raw_rows = raw-rows $state
          $state.selected = (
            $raw_rows
            | enumerate
            | where {|item| $item.item.id == $search_result.jump.row.id }
            | get -o 0.index
            | default $state.selected
          )
          $state = clamp-selection $state $raw_rows
          $current_header = header $state
        }
      } else {
        let result = handle-key $state $raw_rows $event
        $state = $result.state
        if $result.quit {
          break
        }

        if $result.reload {
          $raw_rows = raw-rows $state
          $current_header = header $state
        }

        $state = clamp-selection $state $raw_rows
      }
    }
  }
  print -n (ansi cursor_on)
  print -n $"(ansi cls)(ansi home)"
}

def handle-key [state: record, rows: list<any>, event: record] {
  mut next = $state
  mut quit = false
  mut reload = false
  let code = $event.code? | default ""

  if $code == "esc" {
    $quit = true
  } else if (is-accept-key $event) {
    let selected = $rows | get -o $state.selected | default null
    if $selected != null {
      $next = accept $state $selected
      $reload = true
    }
  } else if (is-back-key $event) {
    if $state.page == "root" {
      $quit = true
    } else {
      $next = pop $state
      $reload = true
    }
  } else if $code == "down" {
    let count = $rows | length
    if $count > 0 {
      $next.selected = if $state.selected >= ($count - 1) {
        0
      } else {
        $state.selected + 1
      }
    }
  } else if $code == "up" {
    let count = $rows | length
    if $count > 0 {
      $next.selected = if $state.selected <= 0 {
        $count - 1
      } else {
        $state.selected - 1
      }
    }
  } else if $code == "r" and "control" in ($event.modifiers? | default []) {
    $reload = true
  }

  {state: $next, quit: $quit, reload: $reload}
}

def build-search-index [] {
  search build-index (initial-state) {|state| raw-rows $state } {|state, page, data|
    goto $state $page $data
  }
}

def raw-rows [state: record] {
  if $state.page == "root" {
    modules | each {|module| $module.root-row}
  } else {
    let module = module-for-page $state.page
    if $module == null { [] } else { do $module.rows $state }
  }
}

def header [state: record] {
  if $state.page == "root" {
    {title: "cmd", current: ""}
  } else {
    let module = module-for-page $state.page
    if $module == null { {title: "cmd", current: ""} } else { do $module.header $state }
  }
}

def accept [state: record, selected: record] {
  let action = $selected.action? | default "noop"
  let data = $selected.data? | default {}

  if $action == "page" {
    goto $state $data.page ($data.data? | default {})
  } else if $action == "apply" {
    let module = module-for-page $state.page
    if $module != null {
      do $module.apply $state $data
    } else {
      $state
    }
  } else {
    $state
  }
}

def module-for-page [page: string] {
  let prefix = $page | split row ":" | get -o 0 | default ""
  modules | where prefix == $prefix | get -o 0 | default null
}

def modules [] {
  [
    (theme entry)
    (helium entry)
    (monitor entry)
    (audio entry)
    (sunset entry)
  ]
}

def initial-state [] {
  {
    page: "root"
    selected: 0
    data: {}
    nav: []
  }
}

def goto [state: record, page: string, data: record = {}] {
  mut next = $state
  $next.nav = ($state.nav | append [{
    page: $state.page
    data: $state.data
    selected: $state.selected
  }])
  $next.page = $page
  $next.data = $data
  $next.selected = 0
  $next
}

def pop [state: record] {
  if ($state.nav | is-empty) {
    mut next = $state
    $next.page = "root"
    $next.data = {}
    $next.selected = 0
    $next.nav = []
    $next
  } else {
    let parent = $state.nav | last
    mut next = $state
    $next.page = $parent.page
    $next.data = $parent.data
    $next.selected = $parent.selected
    $next.nav = $state.nav | drop
    $next
  }
}

def draw [header: record, state: record, rows: list<any>] {
  print -n $"(ansi cls)(ansi home)"
  let width = (term size).columns - 1
  print $"(ansi attr_bold)($header.title)(ansi reset)"
  let current = $header.current? | default ""
  if not ($current | is-empty) {
    let current_label = $header.current-label? | default "current"
    print $"(ansi attr_dimmed)($current_label): ($current)(ansi reset)"
  }
  print ""

  if ($rows | is-empty) {
    print "(no rows)"
  } else {
    $rows | enumerate | each {|item|
      let row = $item.item
      let selected = $item.index == $state.selected
      let marker = if ($row.active? | default false) { "*" } else { " " }
      let prefix = if $selected { ">" } else { " " }
      let right = $row.right? | default ""
      let label_width = if ($row.wide? | default false) {
        [($width - ($right | str length) - 4) 1] | math max
      } else {
        34
      }
      let label = pad-right $"($marker) ($row.label)" $label_width
      let line = pad-right $"($prefix) ($label) ($right)" $width

      if $selected {
        print $"(ansi attr_bold)(ansi attr_reverse)($line)(ansi reset)"
      } else {
        print $line
      }
    } | ignore
  }
}

def clamp-selection [state: record, rows: list<any>] {
  mut next = $state
  let count = $rows | length

  if $count <= 0 {
    $next.selected = 0
  } else if $next.selected >= $count {
    $next.selected = $count - 1
  } else if $next.selected < 0 {
    $next.selected = 0
  }

  $next
}

def is-accept-key [event: record] {
  let code = $event.code? | default ""
  let mods = $event.modifiers? | default []
  $code in ["enter" "right"] or ($code == "l" and "control" in $mods)
}

def is-back-key [event: record] {
  let code = $event.code? | default ""
  let mods = $event.modifiers? | default []
  $code == "left" or ($code == "h" and "control" in $mods)
}

def pad-right [text: string, width: int] {
  let size = $text | str length
  if $size >= $width {
    $text | str substring 0..($width - 1)
  } else {
    $"($text)(char space | fill -a l -c ' ' -w ($width - $size))"
  }
}
