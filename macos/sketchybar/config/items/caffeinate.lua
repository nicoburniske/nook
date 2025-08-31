local state = require("state").load()
local sbar = state.sbar

local caffeinate = sbar.add("item", "caffeinate", {
  position = "right",
  icon = {
    string = "􀋦",
  },
  width = state.ICON_WIDTH,
  align = "center",
  label = { drawing = false },
})

local function update_caffeinate()
  sbar.exec("pmset -g assertions | grep 'caffeinate' | awk '{print $2}' | cut -d '(' -f1 | head -n 1", function(result)
    local pid = result:gsub("\n", "")
    local icon = (pid and pid ~= "") and "􀋨" or "􀋦"

    caffeinate:set({
      icon = { string = icon },
    })
  end)
end

caffeinate:subscribe("mouse.clicked", function(env)
  sbar.exec("pmset -g assertions | grep 'caffeinate' | awk '{print $2}' | cut -d '(' -f1 | head -n 1", function(result)
    local pid = result:gsub("\n", "")

    if pid and pid ~= "" then
      -- Kill existing caffeinate process
      sbar.exec("kill -9 " .. pid, function()
        caffeinate:set({
          icon = { string = "􀋦" },
        })
      end)
    else
      -- Start new caffeinate process
      sbar.exec("caffeinate -id &", function()
        caffeinate:set({
          icon = { string = "􀋨" },
        })
      end)
    end
  end)
end)

caffeinate:subscribe({ "routine", "forced" }, function(env)
  update_caffeinate()
end)

update_caffeinate()
