local state = require("state").load()
local sbar = state.sbar

local sleep = sbar.add("item", "sleep", {
  position = "right",
  icon = {
    string = "􀷄",
  },
  width = state.ICON_WIDTH,
  align = "center",
  label = { drawing = false },
})

sleep:subscribe("mouse.clicked", function(env)
  sbar.exec("osascript -e 'tell application \"System Events\" to sleep'")
end)
