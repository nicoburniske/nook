local state = require("state").load()
local sbar = state.sbar

sbar.begin_config()

sbar.bar({
  position = "top",
  topmost = "window",
  sticky = false,
  height = 38,
  color = state.THEME.bar,
  border_color = state.THEME.bar_border,
  blur_radius = 50,
  padding_left = 10,
  padding_right = 10,
})

sbar.default({
  updates = "when_shown",
  icon = {
    font = {
      family = state.ICON_FONT,
      style = "Bold",
      size = 14.0,
    },
    color = state.THEME.icon,
    highlight_color = state.THEME.highlight,
    padding_left = state.PADDINGS,
    padding_right = state.PADDINGS,
  },
  label = {
    font = {
      family = state.FONT,
      style = "Regular",
      size = 13.0,
    },
    color = state.THEME.label,
    highlight_color = state.THEME.highlight,
  },

  padding_right = state.PADDINGS,
  padding_left = state.PADDINGS,

  popup = {
    blur_radius = 50,
    background = {
      border_width = 0,
      corner_radius = 5,
      border_color = state.THEME.popup_border,
      color = state.THEME.popup_background,
    },
  },

  background = {
    height = 24,
    border_width = 1,
    corner_radius = 5,
  },
})

-- left side
require("items.window_title")
require("items.media")

-- right side
require("items.sleep")
require("items.clock")
require("items.battery")
require("items.cpu")
require("items.theme")
require("items.caffeinate")
require("items.volume")

sbar.end_config()
sbar.event_loop()
