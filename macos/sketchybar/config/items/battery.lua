local state = require("state").load()
local sbar = state.sbar

local battery = sbar.add("item", "battery", {
  position = "right",
  update_freq = 60,
  updates = true,
  drawing = false,
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
    padding_right = 8,
  },
  align = "center",
})

local function update_battery()
  sbar.exec("pmset -g batt", function(result)
    local percentage = result:match("(%d+)%%")
    local charging = result:match("AC Power")

    -- If no battery info (desktop Mac), hide the item
    if not percentage then
      battery:set({ drawing = false })
      return
    end

    percentage = tonumber(percentage)
    local icon = ""
    local color = state.THEME.icon

    if percentage >= 90 then
      icon = "􀛨"
    elseif percentage >= 60 then
      icon = "􀺸"
    elseif percentage >= 30 then
      icon = "􀺶"
    elseif percentage >= 10 then
      icon = "􀛩"
    else
      icon = "􀛪"
      color = state.THEME.red
    end

    if charging then
      icon = "􀢋"
    end

    battery:set({
      icon = {
        string = icon,
        color = color,
      },
      label = {
        string = percentage .. "%",
      },
      drawing = true,
    })
  end)
end

battery:subscribe({ "power_source_change", "system_woke", "routine" }, function(env)
  update_battery()
end)

update_battery()
