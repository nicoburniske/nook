local state = require("state").load()
local sbar = state.sbar

local log_file = "/tmp/sketchybar-theme.log"

local function log(msg)
  local f = io.open(log_file, "a")
  if f then
    f:write(os.date("%Y-%m-%d %H:%M:%S") .. " " .. msg .. "\n")
    f:close()
  end
end

local function theme_icon(polarity)
  if polarity == "dark" then
    return "􀆺"
  else
    return "􀆭"
  end
end

local theme_trigger = sbar.add("item", "theme", {
  position = "right",
  icon = {
    string = theme_icon(state.THEME.polarity),
  },
  width = state.ICON_WIDTH,
  align = "center",
  label = { drawing = false },
  popup = {
    align = "center",
    height = 30,
  },
})

local function update_theme_icon()
  log("Updating icon, polarity=" .. tostring(state.THEME.polarity))
  theme_trigger:set({
    icon = { string = theme_icon(state.THEME.polarity) },
  })
end

-- for _, theme in ipairs(state.THEMES) do
--   log("Creating popup item for theme_trigger: " .. theme.slug)
--   local popup_item = sbar.add("item", "theme.popup." .. theme.slug, {
--     position = "popup.theme",
--     width = 200,
--     icon = {
--       string = theme_icon(theme.polarity),
--       padding_right = 8,
--     },
--     label = {
--       string = theme.slug,
--       padding_left = 0,
--     },
--     background = {
--       color = state.THEME.background,
--       corner_radius = 4,
--       height = 24,
--       padding_left = 4,
--       padding_right = 4,
--     },
--   })
--   popup_item:subscribe("mouse.clicked", function(env)
--     log("Theme selected: " .. theme.slug)
--     theme_trigger:set({ popup = { drawing = false } })
--     os.execute(
--       state.FLAKE_ROOT .. "/result/specialisation/" .. theme.slug .. "/activate" .. "> /tmp/theme-switch.log 2>&1 &"
--     )
--     sbar.exec("sleep 5", function()
--       update_theme_icon()
--     end)
--   end)

--   popup_item:subscribe("mouse.entered", function(env)
--     popup_item:set({
--       background = { color = state.THEME.highlight },
--     })
--   end)

--   popup_item:subscribe("mouse.exited", function(env)
--     popup_item:set({
--       background = { color = state.THEME.background },
--     })
--   end)
-- end

theme_trigger:subscribe({
  "mouse.exited",
  "mouse.exited.global",
}, function(env)
  log("Mouse exit event - hiding popup")
  theme_trigger:set({ popup = { drawing = false } })
end)

theme_trigger:subscribe("mouse.entered", function(env)
  log("Mouse entered - showing popup")
  theme_trigger:set({ popup = { drawing = true } })
end)

theme_trigger:subscribe({ "system_woke", "routine", "forced" }, function(env)
  update_theme_icon()
end)

update_theme_icon()
