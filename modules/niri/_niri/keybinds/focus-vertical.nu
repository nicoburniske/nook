def main [direction: string] {
  if $direction not-in ["up" "down"] {
    exit 2
  }

  let window_action = $"focus-window-($direction)"
  let workspace_action = $"focus-workspace-($direction)"
  let windows = ^niri msg --json windows | from json
  let focused = $windows | where is_focused | get -o 0

  if $focused == null {
    ^niri msg action $workspace_action
    return
  }

  let focused_position = $focused.layout.pos_in_scrolling_layout?

  if $focused.is_floating or $focused_position == null {
    ^niri msg action $window_action
    return
  }

  let focused_column = $focused_position | get 0
  let focused_row = $focused_position | get 1
  let has_window = $windows | any {|window|
    let position = $window.layout.pos_in_scrolling_layout?
    if $position == null {
      false
    } else {
      let is_window_in_direction = if $direction == "up" { ($position | get 1) < $focused_row } else { ($position | get 1) > $focused_row }
      $window.workspace_id == $focused.workspace_id and $window.is_floating == false and ($position | get 0) == $focused_column and $is_window_in_direction
    }
  }

  if $has_window {
    ^niri msg action $window_action
  } else {
    ^niri msg action $workspace_action
  }
}
