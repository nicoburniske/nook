hs.logger.defaultLogLevel = 'info'
local log = hs.logger.new('init', 'info')

hs.pathwatcher.new(os.getenv("HOME") .. "/.hammerspoon/", hs.reload):start()
hs.alert.show("Hammerspoon loaded")

require("control_escape")
require("window_management")
require("app_launcher")
