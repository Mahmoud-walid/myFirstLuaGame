-- src/network/net.lua
local utils = require("utils")
local socket = require("socket.core")
local M = {}

-- state
M.server = nil
M.clients = {} -- for host: { clientSocket -> id }
M.client = nil -- for client mode
M.onReceive = nil -- callback(msg, clientid)
M.running = false

local receive_buffer = ""

-- host
function M.startHost(port)
    port = port or 12345
    M.server = assert(socket.bind("*", port))
    M.server:settimeout(0)
    M.clients = {}
    M.running = true
    utils.printWithPath("Host started on port " .. port)
    -- spawn a coroutine to accept clients and receive data (non-blocking)
    M._host_thread = coroutine.create(function()
        while M.running do
            local client = M.server:accept()
            if client then
                client:settimeout(0)
                table.insert(M.clients, client)
                utils.printWithPath("Client connected")
            end
            -- read from clients
            for i, c in ipairs(M.clients) do
                local s, status, partial = c:receive('*l')
                if s then
                    if M.onReceive then
                        M.onReceive(s, tostring(c))
                    end
                elseif partial and #partial > 0 then
                    if M.onReceive then
                        M.onReceive(partial, tostring(c))
                    end
                end
            end
            socket.sleep(0.01)
        end
    end)
    -- run immediately (non blocking) in love.update via tick
    M._host_tick = function()
        if coroutine.status(M._host_thread) ~= "dead" then
            local ok, err = coroutine.resume(M._host_thread)
            if not ok then
                utils.printWithPath("Host thread error: " .. err)
            end
        end
    end
    -- register tick to love.update by monkey patching love.update is avoided; user states call M.tick()
end

function M.tick()
    -- call this in love.update to service network
    if M.server then
        -- accept new clients
        local client = M.server:accept()
        while client do
            client:settimeout(0)
            table.insert(M.clients, client)
            utils.printWithPath("New client connected")
            client = M.server:accept()
        end
        -- read from clients
        for i = #M.clients, 1, -1 do
            local c = M.clients[i]
            local line, err = c:receive('*l')
            if line then
                if M.onReceive then
                    M.onReceive(line, tostring(c))
                end
            else
                if err == "closed" then
                    utils.printWithPath("Client disconnected")
                    table.remove(M.clients, i)
                end
            end
        end
    end

    if M.client then
        -- read from server
        local line, err = M.client:receive('*l')
        if line then if M.onReceive then M.onReceive(line, "server") end end
    end
end

function M.sendToClient(csocket, text)
    if csocket then pcall(function() csocket:send(text .. "\n") end) end
end

function M.broadcast(text)
    if M.server then
        for _, c in ipairs(M.clients) do
            pcall(function() c:send(text .. "\n") end)
        end
        -- also call onReceive locally for host
        if M.onReceive then M.onReceive(text, "host") end
    end
end

function M.connectToHost(host, port)
    port = port or 12345
    local sock, err = socket.tcp()
    if not sock then return nil, err end
    sock:settimeout(2)
    local ok, err2 = sock:connect(host, port)
    if not ok then return nil, err2 end
    sock:settimeout(0)
    M.client = sock
    utils.printWithPath("Connected to host " .. host .. port)
    return true
end

function M.send(text)
    if M.client then pcall(function() M.client:send(text .. "\n") end) end
end

function M.stop()
    M.running = false
    if M.server then
        for _, c in ipairs(M.clients) do pcall(function() c:close() end) end
        pcall(function() M.server:close() end)
        M.server = nil
        M.clients = {}
    end
    if M.client then
        pcall(function() M.client:close() end)
        M.client = nil
    end
end

return M
