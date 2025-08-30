local M = {}
local loaded = false

function M.load()
  if loaded then
    return M
  end

  local cjson = require("cjson")
  local config_path = os.getenv("HOME") .. "/.config/sketchybar/config.json"
  local f = io.open(config_path, "r")
  if not f then
    error("Could not open config file: " .. config_path)
  end

  local content = f:read("*all")
  f:close()

  local config = cjson.decode(content)

  M.THEME = config.theme
  M.THEMES = config.themes
  M.FONT = config.font
  M.ICON_FONT = config.icon_font
  M.PADDINGS = config.paddings
  M.ICON_WIDTH = config.icon_width
  M.FLAKE_ROOT = config.flake_root

  M.sbar = require("sketchybar")

  loaded = true
  return M
end

return M
