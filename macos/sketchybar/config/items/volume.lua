local state = require("state").load()
local sbar = state.sbar

local volume = sbar.add("item", "volume", {
  position = "right",
  icon = {
    string = "􀊩",
  },
  width = state.ICON_WIDTH,
  align = "center",
  label = { drawing = false },
})

local function set_volume_icon(volume_level)
  local icon = "􀊩"
  local highlight = false

  volume_level = tonumber(volume_level) or 0

  if volume_level >= 60 then
    icon = "􀊩"
  elseif volume_level >= 30 then
    icon = "􀊧"
  elseif volume_level > 0 then
    icon = "􀊥"
  else
    icon = "􀊣"
    highlight = true
  end

  volume:set({
    icon = {
      string = icon,
      highlight = highlight,
    },
  })
end

local function update_volume()
  sbar.exec("osascript -e 'output volume of (get volume settings)'", function(result)
    local volume_level = result:gsub("\n", "")
    set_volume_icon(volume_level)
  end)
end

volume:subscribe("mouse.clicked", function(env)
  sbar.exec("osascript -e 'output muted of (get volume settings)'", function(result)
    local is_muted = result:gsub("\n", "") == "true"

    if is_muted then
      sbar.exec("osascript -e 'set volume output muted false'", function()
        update_volume()
      end)
    else
      sbar.exec("osascript -e 'set volume output muted true'", function()
        set_volume_icon(0)
      end)
    end
  end)
end)

volume:subscribe("volume_change", function(env)
  if env.INFO then
    set_volume_icon(env.INFO)
  else
    update_volume()
  end
end)

volume:subscribe({ "routine", "forced" }, function(env)
  update_volume()
end)

update_volume()
