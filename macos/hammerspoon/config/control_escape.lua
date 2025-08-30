-- Control/Escape functionality
-- Tap control for escape, hold for control
-- Based on https://github.com/jasonrudolph/ControlEscape.spoon

local obj = {}
obj.sendEscape = false
obj.lastModifiers = {}

-- If `control` is held for this long, don't send `escape`
local CANCEL_DELAY_SECONDS = 0.150
obj.controlKeyTimer = hs.timer.delayed.new(CANCEL_DELAY_SECONDS, function()
  obj.sendEscape = false
end)

-- Create an eventtap to run each time the modifier keys change
obj.controlTap = hs.eventtap.new({hs.eventtap.event.types.flagsChanged},
  function(event)
    local newModifiers = event:getFlags()

    -- If this change to the modifier keys does not involve a *change* to the
    -- up/down state of the `control` key, then don't take any action.
    if obj.lastModifiers['ctrl'] == newModifiers['ctrl'] then
      return false
    end

    -- If the `control` key has changed to the down state, then start the
    -- timer. If the `control` key changes to the up state before the timer
    -- expires, then send `escape`.
    if not obj.lastModifiers['ctrl'] then
      obj.lastModifiers = newModifiers
      obj.sendEscape = true
      obj.controlKeyTimer:start()
    else
      if obj.sendEscape then
        hs.eventtap.keyStroke({}, 'escape', 1)
      end
      obj.lastModifiers = newModifiers
      obj.controlKeyTimer:stop()
    end
    return false
  end
)

-- Create an eventtap to run each time a normal key enters the down state
-- We only want to send `escape` if `control` is pressed and released in isolation
obj.keyDownEventTap = hs.eventtap.new({hs.eventtap.event.types.keyDown},
  function(event)
    obj.sendEscape = false
    return false
  end
)

-- Start the functionality
obj.controlTap:start()
obj.keyDownEventTap:start()

hs.logger.new('control_escape', 'info'):i("Control/Escape loaded")

return obj