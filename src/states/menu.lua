-- src/states/menu.lua
local utils = require('utils')
local gamestateHump = require("hump.gamestate")
local suit = require("suit")
local net = require("network.net")
local gameplayState = require('states.gameplay')

local menu = {}

function menu:init()
    utils.printWithPath('Menu state Initialized')
    love.mouse.setVisible(true)

    self.playerName = {text = "Player" .. love.math.random(100, 999)}
    self.join_ip = {text = "127.0.0.1"}
    self.multiplayer_port = {text = "12345"}
    self.isMultiplayerSelected = false
    self.isJoiningGame = false
    self.multiplayerMessage = ""
end

function menu:enter()
    love.mouse.setVisible(true)
    utils.printWithPath('Entering menu state')
    net.stop()
    self.multiplayerMessage = ""
end

function menu:update(dt)
    suit.updateMouse(love.mouse.getX(), love.mouse.getY(), love.mouse.isDown(1))

    local screenWidth, screenHeight = love.graphics.getDimensions()
    local x = (screenWidth - 400) / 2
    local y = (screenHeight - 500) / 2

    suit.layout:reset(x, y)
    suit.layout:padding(10, 10)

    suit.Label("🎮 Numbers Game", {align = "center"}, suit.layout:row(400, 30))
    suit.layout:row()

    -- Player name
    suit.Label("Your Name:", {align = "left"}, suit.layout:row(400, 20))
    suit.Input(self.playerName, suit.layout:row(400, 30))
    suit.layout:row()

    -- Single Player
    if suit.Button("Start Single Player Game", suit.layout:row(400, 40)).hit then
        self.isMultiplayerSelected = false
        gameplayState:setGameMode('single')
        gameplayState.currentPlayer = {
            name = self.playerName.text,
            score = 0,
            isLocal = true
        }
        gamestateHump.switch(gameplayState)
    end

    suit.layout:row()
    suit.Label("Or Play Multiplayer", {align = "center"},
               suit.layout:row(400, 20))
    suit.layout:row()

    if not self.isMultiplayerSelected then
        if suit.Button("Multiplayer Options", suit.layout:row(400, 40)).hit then
            self.isMultiplayerSelected = true
        end
    else
        suit.layout:push(suit.layout:row(400, 40))
        if suit.Button("Host Game", suit.layout:col(195)).hit then
            self.isJoiningGame = false
            net.stop()
            local port = tonumber(self.multiplayer_port.text)
            if port then
                local success, err = net.startHost(port)
                if success then
                    self.multiplayerMessage =
                        "Hosting game on port " .. port ..
                            ". Waiting for players..."
                    gameplayState:setGameMode('multiplayer')
                    gameplayState.isHost = true
                    gameplayState.isConnected = true
                    gameplayState.currentPlayer.name = self.playerName.text
                    gameplayState.players = {
                        {name = self.playerName.text, score = 0, isLocal = true}
                    }
                    gamestateHump.switch(gameplayState)
                else
                    self.multiplayerMessage =
                        "Error hosting: " .. (err or "Unknown error")
                    net.stop()
                end
            else
                self.multiplayerMessage = "Invalid port number."
            end
        end

        if suit.Button("Join Game", suit.layout:col(195)).hit then
            self.isJoiningGame = true
        end
        suit.layout:pop()
        suit.layout:row()

        if self.isJoiningGame then
            suit.Label("Server IP:", {align = "left"}, suit.layout:row(400, 20))
            suit.Input(self.join_ip, suit.layout:row(400, 30))
            suit.Label("Server Port:", {align = "left"},
                       suit.layout:row(400, 20))
            suit.Input(self.multiplayer_port, suit.layout:row(400, 30))
            suit.layout:row()

            if suit.Button("Connect to Server", suit.layout:row(400, 40)).hit then
                net.stop()
                local port = tonumber(self.multiplayer_port.text)
                if port then
                    self.multiplayerMessage =
                        "Attempting to connect to " .. self.join_ip.text .. ":" ..
                            port .. "..."
                    local success, err =
                        net.connectToHost(self.join_ip.text, port)
                    if success then
                        self.multiplayerMessage = "Connected to server!"
                        gameplayState:setGameMode('multiplayer')
                        gameplayState.isHost = false
                        gameplayState.isConnected = true
                        gameplayState.currentPlayer.name = self.playerName.text
                        gameplayState.players = {
                            {
                                name = self.playerName.text,
                                score = 0,
                                isLocal = true
                            }
                        }
                        gamestateHump.switch(gameplayState)
                    else
                        self.multiplayerMessage =
                            "Connection failed: " .. (err or "Unknown error")
                        net.stop()
                    end
                else
                    self.multiplayerMessage = "Invalid port number."
                end
            end
            suit.layout:row()
        end

        if suit.Button("Back to Main Options", suit.layout:row(400, 30)).hit then
            self.isMultiplayerSelected = false
            self.isJoiningGame = false
            self.multiplayerMessage = ""
        end
    end

    if self.multiplayerMessage ~= "" then
        suit.layout:row()
        love.graphics.setColor(1, 0.8, 0.2)
        love.graphics.printf(self.multiplayerMessage, x,
                             suit.layout:row(400, 30), 400, "left")
        love.graphics.setColor(1, 1, 1)
    end

    suit.layout:row()
    if suit.Button("Quit Game", {color = {bg = {0.7, 0.2, 0.2}}},
                   suit.layout:row(400, 30)).hit then love.event.quit() end
end

function menu:draw()
    love.graphics.setColor(0.1, 0.1, 0.15, 1)
    love.graphics.rectangle("fill", 0, 0, love.graphics.getWidth(),
                            love.graphics.getHeight())

    suit.draw()
end

-- function menu:mousepressed(x, y, button) suit.mousepressed(x, y, button) end

-- function menu:mousereleased(x, y, button) suit.mousereleased(x, y, button) end

function menu:textinput(t) suit.textinput(t) end

function menu:keypressed(key)
    if key == "escape" then love.event.quit() end
    suit.keypressed(key)
end

-- function menu:keyreleased(key) suit.keyreleased(key) end

function menu:resize(w, h)
    -- Not needed in SUIT generally
end

return menu
