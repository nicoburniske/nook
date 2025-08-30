local log = hs.logger.new('app_launcher', 'info')

-- Enable Spotlight for better app name resolution
hs.application.enableSpotlightForNameSearches(true)

local apps = {
    ["1"] = "Ghostty",
    ["2"] = "Zen",
    ["3"] = "Spotify",
    ["4"] = "Roam",
    ["5"] = "Roam",
}

local function launchOrToggle(appName)
    return function()
        local app = hs.application.get(appName)

        if app then
            local focusedWindow = hs.window.focusedWindow()
            local appHasFocus = false

            if focusedWindow then
                appHasFocus = focusedWindow:application() == app
            end

            if appHasFocus then
                app:hide()
                log.i("Hidden: " .. appName)
            else
                app:activate()
                log.i("Focused: " .. appName)
            end
        else
            local launched = hs.application.launchOrFocus(appName)

            if launched then
                log.i("Launched: " .. appName)
            else
                hs.alert.show("Could not find: " .. appName)
                log.w("Failed to launch: " .. appName)
            end
        end
    end
end

local function setupQuickSwitch()
    for key, appName in pairs(apps) do
        hs.hotkey.bind({"option"}, key, launchOrToggle(appName))
    end
end

local function showAppWindows()
    local chooser = hs.chooser.new(function(choice)
        if choice then
            local app = hs.application.get(choice.appName)
            if app then
                local win = app:getWindow(choice.text)
                if win then
                    win:focus()
                end
            end
        end
    end)
    
    local choices = {}
    for _, app in ipairs(hs.application.runningApplications()) do
        for _, win in ipairs(app:allWindows()) do
            if win:isStandard() and win:title() ~= "" then
                table.insert(choices, {
                    text = win:title(),
                    subText = app:name(),
                    appName = app:name(),
                    image = hs.image.imageFromAppBundle(app:bundleID())
                })
            end
        end
    end
    
    chooser:choices(choices)
    chooser:show()
end

hs.hotkey.bind({"option"}, "a", showAppWindows)

hs.hotkey.bind({"option"}, "d", function()
    local startTime = hs.timer.secondsSinceEpoch()
    local seenApps = {}
    local hiddenCount = 0

    for _, win in ipairs(hs.window.visibleWindows()) do
        local app = win:application()
        if app and not seenApps[app:pid()] then
            seenApps[app:pid()] = true
            app:hide()
            hiddenCount = hiddenCount + 1
        end
    end

    local endTime = hs.timer.secondsSinceEpoch()
    log.i(string.format("Hidden %d apps in %.3f seconds (visible windows approach)", hiddenCount, endTime - startTime))
end)

setupQuickSwitch()

log.i("Application launcher loaded")
