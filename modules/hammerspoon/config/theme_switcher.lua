local log = hs.logger.new("theme_switcher", "info")

local M = {}

local function runThemeSwitch()
  hs.notify.new({
    title = "Theme Switcher",
    informativeText = "Opening theme selector...",
  }):send()

  local task = hs.task.new("/usr/bin/env", function(exitCode, stdOut, stdErr)
    if exitCode == 0 then
      return
    end

    local message = "theme-switch failed"
    if stdErr and stdErr ~= "" then
      message = stdErr
    elseif stdOut and stdOut ~= "" then
      message = stdOut
    end

    log.e(message)
    hs.notify.new({
      title = "Theme Switcher",
      informativeText = "Theme switch failed. Check Hammerspoon console.",
    }):send()
  end, {"theme-switch"})

  if not task then
    log.e("failed to start theme-switch task")
    hs.notify.new({
      title = "Theme Switcher",
      informativeText = "Could not launch theme selector.",
    }):send()
    return
  end

  task:start()
end

function M.init()
  hs.hotkey.bind({"ctrl", "cmd"}, "space", function()
    runThemeSwitch()
  end)

  log.i("Theme switcher initialized (Ctrl+Cmd+Space)")
end

return M
