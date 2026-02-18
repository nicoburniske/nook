local obj = {}
obj.sendEscape = false
obj.lastModifiers = {}

local CANCEL_DELAY_SECONDS = 0.150
obj.controlKeyTimer = hs.timer.delayed.new(CANCEL_DELAY_SECONDS, function()
  obj.sendEscape = false
end)

obj.controlTap = hs.eventtap.new({hs.eventtap.event.types.flagsChanged},
  function(event)
    local newModifiers = event:getFlags()

    if obj.lastModifiers["ctrl"] == newModifiers["ctrl"] then
      return false
    end

    if not obj.lastModifiers["ctrl"] then
      obj.lastModifiers = newModifiers
      obj.sendEscape = true
      obj.controlKeyTimer:start()
    else
      if obj.sendEscape then
        hs.eventtap.keyStroke({}, "escape", 1)
      end
      obj.lastModifiers = newModifiers
      obj.controlKeyTimer:stop()
    end
    return false
  end
)

obj.keyDownEventTap = hs.eventtap.new({hs.eventtap.event.types.keyDown},
  function(_)
    obj.sendEscape = false
    return false
  end
)

obj.controlTap:start()
obj.keyDownEventTap:start()

hs.logger.new("control_escape", "info"):i("Control/Escape loaded")

return obj
