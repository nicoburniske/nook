hs.logger.defaultLogLevel = "info"

require("hs.ipc")

hs.pathwatcher.new(os.getenv("HOME") .. "/.hammerspoon/", hs.reload):start()
hs.alert.show("Hammerspoon loaded")

require("control_escape")
require("theme_switcher").init()
