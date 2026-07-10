export def initial [] {
  {
    active: false
    query: ""
    selected: 0
    index: null
  }
}

export def handle-event [search: record, event: record, build_index: closure] {
  if not $search.active and not (is-char $event) {
    return {search: $search, jump: null, handled: false}
  }

  mut next = $search
  mut jump = null
  let code = $event.code? | default ""
  let mods = $event.modifiers? | default []

  if not $search.active {
    if $next.index == null {
      $next.index = do $build_index
    }
    $next.active = true
    $next.query = $code
    $next.selected = 0
  } else if $code == "esc" {
    $next = reset $next
  } else if $code == "backspace" {
    $next.query = $search.query | split chars | drop | str join
    if ($next.query | is-empty) {
      $next = reset $next
    } else {
      $next.selected = 0
    }
  } else if $code == "enter" {
    $jump = results $search | get -o $search.selected | default null
    if $jump != null {
      $next = reset $next
    }
  } else if $code == "down" {
    $next.selected = move-selection $search.selected (results $search | length) 1
  } else if $code == "up" {
    $next.selected = move-selection $search.selected (results $search | length) (-1)
  } else if $code == "r" and "control" in $mods {
    $next.index = do $build_index
    $next.selected = 0
  } else if (is-char $event) {
    $next.query = $search.query + $code
    $next.selected = 0
  }

  {search: $next, jump: $jump, handled: true}
}

export def build-index [root: record, load_rows: closure, open_page: closure] {
  index-page $root [] 0 $load_rows $open_page
}

def index-page [
  state: record
  path: list<string>
  depth: int
  load_rows: closure
  open_page: closure
] {
  if $depth >= 16 {
    return []
  }

  let rows = try { do $load_rows $state } catch { [] }

  $rows
  | enumerate
  | reduce --fold [] {|item, entries|
    let row = $item.item
    let row_path = $path | append $row.label
    mut containing_state = $state
    $containing_state.selected = $item.index
    let entry = {
      path: ($row_path | str join " > ")
      state: $containing_state
      row: $row
    }
    let action = $row.action? | default "noop"

    if $action == "page" {
      let data = $row.data? | default {}
      let child = do $open_page $containing_state $data.page ($data.data? | default {})
      $entries
      | append $entry
      | append (index-page $child $row_path ($depth + 1) $load_rows $open_page)
    } else {
      $entries | append $entry
    }
  }
}

def reset [search: record] {
  (initial) | update index $search.index
}

def is-char [event: record] {
  let mods = $event.modifiers? | default []
  (($event.key_type? | default "") == "char") and (not ($mods | any {|modifier|
    $modifier in ["control" "alt" "super" "hyper" "meta"]
  }))
}

def results [search: record] {
  $search.index
  | each {|entry|
    let score = fuzzy-score $entry.path $search.query
    if $score == null { null } else { $entry | merge {score: $score} }
  }
  | compact
  | sort-by --reverse score
}

def fuzzy-score [candidate: string, query: string] {
  let haystack = $candidate | str downcase
  let needle = $query | str downcase | split chars
  mut offset = 0
  mut previous = -2
  mut score = 0

  for character in $needle {
    let position = $haystack | str index-of --grapheme-clusters $character --range $offset..
    if $position < 0 {
      return null
    }

    $score = $score + (if $position == ($previous + 1) { 20 } else { 5 }) - $position
    $previous = $position
    $offset = $position + 1
  }

  $score - (($haystack | str length) - ($needle | length))
}

def move-selection [selected: int, count: int, delta: int] {
  if $count <= 0 {
    0
  } else if $delta > 0 {
    if $selected >= ($count - 1) { 0 } else { $selected + 1 }
  } else {
    if $selected <= 0 { $count - 1 } else { $selected - 1 }
  }
}

export def view [search: record] {
  let max_rows = [
    ((term size).rows - 4)
    1
  ] | math max
  let start = if $search.selected >= $max_rows {
    $search.selected - $max_rows + 1
  } else {
    0
  }
  let rows = results $search | skip $start | first $max_rows | each {|result|
    {
      label: $result.path
      right: ($result.row.right? | default "")
      active: ($result.row.active? | default false)
      wide: true
    }
  }
  {
    header: {title: "cmd > search", current: $search.query, current-label: "query"}
    state: {
      selected: ($search.selected - $start)
    }
    rows: $rows
  }
}
