local log = hs.logger.new('window_management', 'info')

local PADDING = 16
local ANIMATION_DURATION = 0
local DOUBLE_TAP_TIMEOUT = 0.4

local lastDirection = nil
local lastDirectionTime = 0
local cycleIndex = {}

local sizeCycles = {
    left = {"left-half", "left-third", "left-two-thirds"},
    right = {"right-half", "right-third", "right-two-thirds"},
    top = {"top-half", "top-third", "top-two-thirds"},
    bottom = {"bottom-half", "bottom-third", "bottom-two-thirds"}
}

local function getFrameWithPadding(screen)
    local frame = screen:frame()
    return {
        x = frame.x + PADDING,
        y = frame.y + PADDING,
        w = frame.w - (PADDING * 2),
        h = frame.h - (PADDING * 2)
    }
end

local function calculateFrame(position, screenFrame)
    local frame = screenFrame
    local newFrame = {}
    
    if position == "left-half" then
        newFrame = {
            x = frame.x,
            y = frame.y,
            w = frame.w / 2 - PADDING / 2,
            h = frame.h
        }
    elseif position == "right-half" then
        newFrame = {
            x = frame.x + frame.w / 2 + PADDING / 2,
            y = frame.y,
            w = frame.w / 2 - PADDING / 2,
            h = frame.h
        }
    elseif position == "top-half" then
        newFrame = {
            x = frame.x,
            y = frame.y,
            w = frame.w,
            h = frame.h / 2 - PADDING / 2
        }
    elseif position == "bottom-half" then
        newFrame = {
            x = frame.x,
            y = frame.y + frame.h / 2 + PADDING / 2,
            w = frame.w,
            h = frame.h / 2 - PADDING / 2
        }
    
    elseif position == "left-third" then
        newFrame = {
            x = frame.x,
            y = frame.y,
            w = frame.w / 3 - PADDING / 2,
            h = frame.h
        }
    elseif position == "right-third" then
        newFrame = {
            x = frame.x + frame.w * 2/3 + PADDING / 2,
            y = frame.y,
            w = frame.w / 3 - PADDING / 2,
            h = frame.h
        }
    elseif position == "top-third" then
        newFrame = {
            x = frame.x,
            y = frame.y,
            w = frame.w,
            h = frame.h / 3 - PADDING / 2
        }
    elseif position == "bottom-third" then
        newFrame = {
            x = frame.x,
            y = frame.y + frame.h * 2/3 + PADDING / 2,
            w = frame.w,
            h = frame.h / 3 - PADDING / 2
        }
    
    elseif position == "left-two-thirds" then
        newFrame = {
            x = frame.x,
            y = frame.y,
            w = frame.w * 2/3 - PADDING / 2,
            h = frame.h
        }
    elseif position == "right-two-thirds" then
        newFrame = {
            x = frame.x + frame.w / 3 + PADDING / 2,
            y = frame.y,
            w = frame.w * 2/3 - PADDING / 2,
            h = frame.h
        }
    elseif position == "top-two-thirds" then
        newFrame = {
            x = frame.x,
            y = frame.y,
            w = frame.w,
            h = frame.h * 2/3 - PADDING / 2
        }
    elseif position == "bottom-two-thirds" then
        newFrame = {
            x = frame.x,
            y = frame.y + frame.h / 3 + PADDING / 2,
            w = frame.w,
            h = frame.h * 2/3 - PADDING / 2
        }
    
    elseif position == "topleft" then
        newFrame = {
            x = frame.x,
            y = frame.y,
            w = frame.w / 2 - PADDING / 2,
            h = frame.h / 2 - PADDING / 2
        }
    elseif position == "topright" then
        newFrame = {
            x = frame.x + frame.w / 2 + PADDING / 2,
            y = frame.y,
            w = frame.w / 2 - PADDING / 2,
            h = frame.h / 2 - PADDING / 2
        }
    elseif position == "bottomleft" then
        newFrame = {
            x = frame.x,
            y = frame.y + frame.h / 2 + PADDING / 2,
            w = frame.w / 2 - PADDING / 2,
            h = frame.h / 2 - PADDING / 2
        }
    elseif position == "bottomright" then
        newFrame = {
            x = frame.x + frame.w / 2 + PADDING / 2,
            y = frame.y + frame.h / 2 + PADDING / 2,
            w = frame.w / 2 - PADDING / 2,
            h = frame.h / 2 - PADDING / 2
        }
    
    elseif position == "maximize" then
        newFrame = frame
    elseif position == "center" then
        newFrame = {
            x = frame.x + frame.w / 8,
            y = frame.y + frame.h / 8,
            w = frame.w * 3/4,
            h = frame.h * 3/4
        }
    end
    
    return newFrame
end

local function moveWindowWithCycle(direction)
    return function()
        local win = hs.window.focusedWindow()
        if not win then
            hs.alert.show("No focused window")
            return
        end
        
        local screen = win:screen()
        local frame = getFrameWithPadding(screen)
        local currentTime = hs.timer.secondsSinceEpoch()
        
        if lastDirection == direction and (currentTime - lastDirectionTime) < DOUBLE_TAP_TIMEOUT then
            cycleIndex[direction] = (cycleIndex[direction] or 0) + 1
            if cycleIndex[direction] > #sizeCycles[direction] then
                cycleIndex[direction] = 1
            end
        else
            cycleIndex[direction] = 1
        end
        
        lastDirection = direction
        lastDirectionTime = currentTime
        
        local position = sizeCycles[direction][cycleIndex[direction]]
        local newFrame = calculateFrame(position, frame)
        
        if newFrame then
            win:setFrame(newFrame, ANIMATION_DURATION)
        end
    end
end

local function moveWindowToPosition(position)
    return function()
        local win = hs.window.focusedWindow()
        if not win then
            hs.alert.show("No focused window")
            return
        end
        
        local screen = win:screen()
        local frame = getFrameWithPadding(screen)
        local newFrame = calculateFrame(position, frame)
        
        if newFrame then
            win:setFrame(newFrame, ANIMATION_DURATION)
        end
    end
end

local mods = {"option"}

hs.hotkey.bind(mods, "h", moveWindowWithCycle("left"))
hs.hotkey.bind(mods, "l", moveWindowWithCycle("right"))
hs.hotkey.bind(mods, "k", moveWindowWithCycle("top"))
hs.hotkey.bind(mods, "j", moveWindowWithCycle("bottom"))

hs.hotkey.bind(mods, "return", moveWindowToPosition("maximize"))

log.i("Window management loaded")
