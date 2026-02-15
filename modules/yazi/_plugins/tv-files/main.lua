return {
    entry = function()
        local permit = ya.hide()
        local child, err = Command("tv")
            :arg("files")
            :stdin(Command.INHERIT)
            :stderr(Command.INHERIT)
            :stdout(Command.PIPED)
            :spawn()

        if not child then
            ya.notify({
                title = "Failed to spawn tv",
                content = tostring(err),
                level = "error",
                timeout = 5,
            })
            return
        end

        local output, err = child:wait_with_output()

        if not output then
            ya.notify({
                title = "Failed to wait for tv",
                content = tostring(err),
                level = "error",
                timeout = 5,
            })
        end

        for line in output.stdout:gmatch("[^\r\n]+") do
            if line ~= "" then
                local path = line:match("^([^:]+)")
                if path then
                    local url = Url(path)
                    ya.emit("reveal", { url, raw = true })
                    break
                end
            end
        end
    end,
}
