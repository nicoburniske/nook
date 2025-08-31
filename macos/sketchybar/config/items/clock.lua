local state = require("state").load()
local sbar = state.sbar

local clock = sbar.add("item", "clock", {
  position = "right",
  icon = { drawing = false },
  update_freq = 10,
  background = {
    color = state.THEME.background,
    corner_radius = 9,
    height = 22,
    padding_left = 5,
    padding_right = 5,
  },
  label = {
    padding_left = 8,
    padding_right = 8,
    string = "loading...",
  },
})

local function update_clock()
  sbar.exec("date '+%a %b %d %H:%M'", function(result)
    if result then
      local label = result:gsub("\n", ""):lower()
      clock:set({
        label = { string = label },
      })
    end
  end)
end

clock:subscribe("mouse.clicked", function(env)
  sbar.exec("open -a Calendar")
end)

clock:subscribe({ "routine", "forced" }, function(env)
  update_clock()
end)

update_clock()
