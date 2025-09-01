local log = hs.logger.new('theme_switcher', 'info')

local M = {}

local function getThemes()
  local themes = {}
  local specDir = os.getenv("HOME") .. "/specialisation"
  local handle = io.popen('ls -1 "' .. specDir .. '" 2>/dev/null')
  if handle then
    for theme in handle:lines() do
      table.insert(themes, {
        text = theme,
        subText = "Switch to " .. theme .. " theme"
      })
    end
    handle:close()
  end
  return themes
end

local function switchTheme(choice)
  if not choice then
    return
  end

  local theme = choice.text
  log.i("Switching to theme: " .. theme)

  hs.notify.new({
    title = "Theme Switcher",
    informativeText = "Switching to " .. theme .. " theme..."
  }):send()

  local task = hs.task.new("/bin/bash",
    function(exitCode, stdOut, stdErr)
      log.i("Theme switch completed with exit code: " .. exitCode)
      if stdOut and stdOut ~= "" then
        log.i("stdout: " .. stdOut)
      end
      if stdErr and stdErr ~= "" then
        log.e("stderr: " .. stdErr)
      end

      if exitCode == 0 then
        hs.notify.new({
          title = "Theme Switcher",
          informativeText = "Successfully switched to " .. theme
        }):send()
      else
        hs.notify.new({
          title = "Theme Switcher",
          informativeText = "Failed to switch theme. Check console for details."
        }):send()
      end
    end,
    { "-c", "/etc/profiles/per-user/nicoburniske/bin/theme-switch '" .. theme .. "' 2>&1" }
  )

  task:start()
end

function M.showChooser()
  local themes = getThemes()

  if #themes == 0 then
    hs.notify.new({
      title = "Theme Switcher",
      informativeText = "No themes available"
    }):send()
    return
  end

  local chooser = hs.chooser.new(switchTheme)
  chooser:choices(themes)
  chooser:searchSubText(true)
  chooser:placeholderText("Select theme...")
  chooser:show()
end

function M.init()
  hs.hotkey.bind({ "alt" }, "t", function()
    M.showChooser()
  end)

  log.i("Theme switcher initialized (Opt+T)")
end

return M
