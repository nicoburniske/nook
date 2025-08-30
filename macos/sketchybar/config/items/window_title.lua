local state = require("state").load()
local sbar = state.sbar

local window_title = sbar.add("item", "window_title", {
  position = "left",
  icon = { drawing = false },
  label = {
    max_chars = 50,
    padding_left = 4,
    padding_right = 4,
  },
  align = "center",
})

local window_divider = sbar.add("item", "window_divider", {
  position = "left",
  icon = {
    string = "│",
    color = state.THEME.highlight,
    padding_left = 8,
    padding_right = 8,
  },
  label = { drawing = false },
})

window_title:subscribe("front_app_switched", function(env)
  if env.INFO then
    window_title:set({
      label = { string = env.INFO:lower() },
    })
  end
end)
