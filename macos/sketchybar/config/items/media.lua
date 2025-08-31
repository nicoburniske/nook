local state = require("state").load()
local sbar = state.sbar

local media = sbar.add("item", "media", {
  position = "left",
  icon = {
    string = "",
    color = state.THEME.icon,
  },
  label = {
    max_chars = 30,
    scroll_duration = 200,
  },
  scroll_texts = true,
  update_freq = 2,
  updates = true,
  drawing = false,
})

local media_divider = sbar.add("item", "media_divider", {
  position = "left",
  icon = {
    string = "│",
    color = state.THEME.highlight,
    padding_left = 8,
    padding_right = 8,
  },
  label = { drawing = false },
  drawing = false,
})

local function update_media()
  sbar.exec("nowplaying-cli get playbackRate 2>/dev/null", function(state_result)
    local state = state_result:gsub("\n", "")

    if state == "1" or state == "0" then
      sbar.exec("nowplaying-cli get title 2>/dev/null", function(title_result)
        local title = title_result:gsub("\n", "")

        if title and title ~= "" then
          sbar.exec("nowplaying-cli get artist 2>/dev/null", function(artist_result)
            local artist = artist_result:gsub("\n", "")
            local label = title

            if artist and artist ~= "" then
              label = title .. " - " .. artist
            end

            if state == "1" then
              media:set({
                label = { string = label:lower() },
                drawing = true,
              })
              media_divider:set({ drawing = true })
            else
              media:set({ drawing = false })
              media_divider:set({ drawing = false })
            end
          end)
        else
          media:set({ drawing = false })
          media_divider:set({ drawing = false })
        end
      end)
    else
      media:set({ drawing = false })
      media_divider:set({ drawing = false })
    end
  end)
end

media:subscribe({ "routine", "forced" }, function(env)
  update_media()
end)

update_media()
