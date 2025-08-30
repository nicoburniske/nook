local state = require("state").load()
local sbar = state.sbar

local cpu = sbar.add("item", "cpu", {
  position = "right",
  icon = {
    string = "􀧓",
    color = state.THEME.icon,
  },
  update_freq = 5,
  background = {
    color = state.THEME.transparent,
    border_color = state.THEME.label,
    border_width = 1,
    corner_radius = 9,
    height = 22,
    padding_left = 5,
    padding_right = 5,
  },
  label = {
    padding_left = 8,
    padding_right = 8,
  },
  align = "center",
})

local function update_cpu()
  sbar.exec("top -l 2 | grep -E '^CPU' | tail -1", function(result)
    -- Parse CPU usage from top output
    -- Example: "CPU usage: 3.70% user, 5.55% sys, 90.74% idle"
    local user = result:match("(%d+%.?%d*)%% user") or "0"
    local sys = result:match("(%d+%.?%d*)%% sys") or "0"

    local total = math.floor(tonumber(user) + tonumber(sys))

    cpu:set({
      label = { string = string.format("%02d%%", total) },
    })
  end)
end

cpu:subscribe({ "routine", "forced" }, function(env)
  update_cpu()
end)

update_cpu()
