local M = {}

function M.printWithPath(msg)
    local co = coroutine.create(function()
        local info = debug.getinfo(1, "S")
        local source = info.source or "unknown"
        if source:sub(1, 1) == "@" then source = source:sub(2) end
        print(msg .. " ---> {{red}}[" .. source .. "]{{end}}")
    end)

    local success, err = coroutine.resume(co)
    if not success then error(err) end
end

return M
