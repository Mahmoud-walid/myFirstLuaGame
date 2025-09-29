-- src/states/gameplay.lua
local utils = require("utils")
local tove = require("tove")
local gamestateHump = require('hump.gamestate')
local TimerModule = require('systems.timer') -- Load the Timer module
local net = require('network.net')
local Grid = require('game.grid')

local gameplay = {}

-- Store global references for game state, to be set by menu
-- This is a temporary measure for simplicity; in a larger app,
-- you might pass these as parameters to gameplay:enter()
gameplay.gameMode = 'single'
gameplay.gameDuration = 60 -- Default duration for multiplayer (can be configured)
gameplay.currentPlayer = {name = "Player", score = 0}
gameplay.players = {} -- List of all players (including local)
gameplay.isHost = false
gameplay.isConnected = false
gameplay.gameStarted = false -- Flag to indicate game has started (after any countdown)

function gameplay:init()
    utils.printWithPath("Initializing gameplay state...")

    self.isGameOver = false
    self.isPaused = false
    self.mainTimer = nil -- Will hold our Timer object
    self.grid = nil -- Will be initialized in enter()

    -- Ensure SVGs are created if not already
    self:createUISVGs()
    utils.printWithPath("Gameplay state initialized successfully!")
end

function gameplay:createUISVGs()
    -- Score panel SVG
    self.scorePanelSVG = tove.newGraphics([[
        <svg width="200" height="60" xmlns="http://www.w3.org/2000/svg">
            <rect x="2" y="2" width="196" height="56" rx="8" ry="8" 
                  fill="#2c3e50" stroke="#34495e" stroke-width="2"/>
        </svg>
    ]], 200)

    -- Timer panel SVG (green)
    self.timerPanelSVG = tove.newGraphics([[
        <svg width="150" height="60" xmlns="http://www.w3.org/2000/svg">
            <rect x="2" y="2" width="146" height="56" rx="8" ry="8" 
                  fill="#27ae60" stroke="#229954" stroke-width="2"/>
        </svg>
    ]], 150)

    -- Timer panel SVG (red for warnings)
    self.timerPanelRedSVG = tove.newGraphics([[
        <svg width="150" height="60" xmlns="http://www.w3.org/2000/svg">
            <rect x="2" y="2" width="146" height="56" rx="8" ry="8" 
                  fill="#e74c3c" stroke="#c0392b" stroke-width="2"/>
        </svg>
    ]], 150)

    -- Game over panel SVG
    self.gameOverSVG = tove.newGraphics([[
        <svg width="400" height="200" xmlns="http://www.w3.org/2000/svg">
            <rect x="5" y="5" width="390" height="190" rx="12" ry="12" 
                  fill="#2c3e50" stroke="#34495e" stroke-width="3" opacity="0.95"/>
            <rect x="10" y="10" width="380" height="180" rx="8" ry="8" 
                  fill="#34495e" stroke="#2c3e50" stroke-width="1"/>
        </svg>
    ]], 400)

    -- Button SVG for game over screen
    self.smallButtonSVG = tove.newGraphics([[
        <svg width="120" height="40" xmlns="http://www.w3.org/2000/svg">
            <rect x="2" y="2" width="116" height="36" rx="6" ry="6" 
                  fill="#3498db" stroke="#2980b9" stroke-width="2"/>
        </svg>
    ]], 120)

    self.smallButtonHoverSVG = tove.newGraphics([[
        <svg width="120" height="40" xmlns="http://www.w3.org/2000/svg">
            <rect x="2" y="2" width="116" height="36" rx="6" ry="6" 
                  fill="#5dade2" stroke="#3498db" stroke-width="2"/>
        </svg>
    ]], 120)
end

-- This function is called from the menu state to set up the game mode
function gameplay:setGameMode(mode)
    self.gameMode = mode
    -- This ensures the gameplay state has the player's name set from the menu
    -- We assume `self.currentPlayer.name` is set in the menu state before switching
end

function gameplay:enter()
    utils.printWithPath("Entering gameplay state. Mode: " .. self.gameMode)
    love.mouse.setVisible(true)

    self.isGameOver = false
    self.isPaused = false
    self.gameStarted = false -- Game starts after any initial countdown or immediately

    local screenWidth, screenHeight = love.graphics.getDimensions()
    self.grid = Grid.new(6, screenWidth, screenHeight)

    -- Initialize the timer based on game mode
    if self.gameMode == 'single' then
        self.mainTimer = TimerModule.Timer.createStopwatch()
        self.mainTimer:start() -- Start immediately for single player
        self.gameStarted = true
    elseif self.gameMode == 'multiplayer' then
        self.mainTimer = TimerModule.Timer.createMultiplayerTimer(
                             gameplay.gameDuration)
        -- In multiplayer, the timer might have a pre-game countdown or start when players are ready
        -- For now, let's start it immediately for testing
        self.mainTimer:start()
        self.gameStarted = true

        -- Initialize players list based on who is local
        if #self.players == 0 then -- If players list is empty (shouldn't be if set by menu)
            table.insert(self.players, {
                name = self.currentPlayer.name,
                score = 0,
                isLocal = true,
                id = "local_player"
            })
        else
            -- Ensure the local player is identified
            local foundLocal = false
            for i, player in ipairs(self.players) do
                if player.isLocal then
                    foundLocal = true;
                    break
                end
            end
            if not foundLocal then
                table.insert(self.players, {
                    name = self.currentPlayer.name,
                    score = 0,
                    isLocal = true,
                    id = "local_player"
                })
            end
        end
    end

    -- Setup network receive callback if connected
    if self.isConnected then
        net.onReceive = function(message, senderId)
            self:handleNetworkMessage(message, senderId)
        end
        -- If host, broadcast initial grid state to new players
        if self.isHost then self:broadcastGameState() end
    end

    -- Button states for game over screen
    self.gameOverButtons = {restart = {hover = false}, menu = {hover = false}}

    utils.printWithPath("✅ Gameplay state entered successfully!")
end

function gameplay:update(dt)
    if not self.isPaused and not self.isGameOver and self.gameStarted then
        -- Update the main game timer
        if self.mainTimer then
            self.mainTimer:update(dt)
            if self.mainTimer:isFinished() then self:endGame() end
        end

        -- Update current player score (assuming local player is always at index 1 for now if single)
        if self.gameMode == 'single' then
            self.currentPlayer.score = self.grid:getScore()
        else
            -- In multiplayer, find the local player and update their score
            for i, player in ipairs(self.players) do
                if player.isLocal then
                    player.score = self.grid:getScore()
                    self.currentPlayer.score = player.score -- Keep currentPlayer updated
                    -- If host, broadcast score update
                    if self.isHost then
                        net.broadcast("SCORE_UPDATE:" .. player.name .. ":" ..
                                          player.score)
                    elseif self.isConnected then
                        -- Client sends its score to the host
                        net.send("CLIENT_SCORE:" .. player.name .. ":" ..
                                     player.score)
                    end
                    break
                end
            end
        end

        -- Check for game over conditions (no more valid moves)
        if not self.grid:hasValidMoves() then self:endGame() end
    end

    -- Update hover states for game over buttons
    if self.isGameOver then
        local mouseX, mouseY = love.mouse.getPosition()
        local screenWidth, screenHeight = love.graphics.getDimensions()
        local panelX = (screenWidth - 400) / 2
        local panelY = (screenHeight - 200) / 2

        local restartX = panelX + 60
        local menuX = panelX + 220
        local buttonY = panelY + 140

        self.gameOverButtons.restart.hover =
            mouseX >= restartX and mouseX <= restartX + 120 and mouseY >=
                buttonY and mouseY <= buttonY + 40

        self.gameOverButtons.menu.hover =
            mouseX >= menuX and mouseX <= menuX + 120 and mouseY >= buttonY and
                mouseY <= buttonY + 40
    end

    -- hump.timer.update(dt) is handled by gamestateHump.update already (in main.lua)
end

function gameplay:endGame()
    if self.isGameOver then return end -- Prevent multiple endGame calls
    self.isGameOver = true
    self.mainTimer:stop()

    if self.gameMode == 'multiplayer' then
        -- Determine winner based on scores
        local winner = self.players[1]
        for _, player in ipairs(self.players) do
            if player.score > winner.score then winner = player end
        end
        self.winner = winner
        utils.printWithPath("Game Over! Winner: " .. winner.name ..
                                " with score " .. winner.score)
        -- If host, broadcast game over and winner
        if self.isHost and self.isConnected then
            net.broadcast("GAME_OVER:" .. winner.name .. ":" .. winner.score)
        end
    else
        utils.printWithPath("Game Over! Final Score: " ..
                                self.currentPlayer.score)
    end
end

function gameplay:draw()
    local screenWidth, screenHeight = love.graphics.getDimensions()

    -- Draw background
    love.graphics.setColor(0.1, 0.1, 0.15, 1)
    love.graphics.rectangle("fill", 0, 0, screenWidth, screenHeight)

    -- Draw UI panels
    self:drawUI()

    -- Draw grid
    if self.grid then self.grid:draw() end

    -- Draw game over overlay
    if self.isGameOver then self:drawGameOver() end

    -- Draw pause overlay
    if self.isPaused then self:drawPause() end

end

function gameplay:drawUI()
    local screenWidth, screenHeight = love.graphics.getDimensions()

    -- Draw score panel
    local scorePanelX = 20
    local scorePanelY = 20
    love.graphics.setColor(1, 1, 1, 1)
    if self.scorePanelSVG and self.scorePanelSVG.draw then
        self.scorePanelSVG:draw(scorePanelX, scorePanelY)
    end

    -- Score text for local player
    love.graphics.setFont(love.graphics.newFont(16))
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.print("Score: " .. (self.currentPlayer.score or 0),
                        scorePanelX + 10, scorePanelY + 12)

    love.graphics.setFont(love.graphics.newFont(12))
    local modeText = (self.gameMode == 'multiplayer') and "Mode: Multiplayer" or
                         "Mode: Single Player"
    love.graphics.print(modeText, scorePanelX + 10, scorePanelY + 35)

    -- Draw timer panel
    local timerPanelX = screenWidth - 170
    local timerPanelY = 20
    love.graphics.setColor(1, 1, 1, 1)

    if self.mainTimer then
        local formattedTime = self.mainTimer:getFormattedTime().formatted
        local timerSVGToUse = self.timerPanelSVG -- Default green

        if self.gameMode == 'multiplayer' and self.mainTimer:isWarningTime() then
            timerSVGToUse = self.timerPanelRedSVG -- Red for warning in multiplayer countdown
        end

        if timerSVGToUse then
            timerSVGToUse:draw(timerPanelX, timerPanelY)
        end
        love.graphics.setFont(love.graphics.newFont(16))
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.printf(formattedTime, timerPanelX + 10, timerPanelY + 12,
                             130, "center")
        love.graphics.setFont(love.graphics.newFont(10))
        local timerLabel = (self.gameMode == 'single') and "Time Played" or
                               "Time Left"
        love.graphics.printf(timerLabel, timerPanelX + 10, timerPanelY + 35,
                             130, "center")
    end

    -- Draw multiplayer player list
    if self.gameMode == 'multiplayer' and #self.players > 0 then
        local playerListX = 20
        local playerListY = 100

        love.graphics.setFont(love.graphics.newFont(14))
        love.graphics.setColor(0.8, 0.8, 0.8, 1)
        love.graphics.print("Players:", playerListX, playerListY)

        -- Sort players by score for scoreboard effect
        table.sort(self.players, function(a, b) return a.score > b.score end)

        for i, player in ipairs(self.players) do
            local y = playerListY + 25 + (i - 1) * 20
            local color = player.isLocal and {0.3, 0.8, 0.3, 1} or
                              {0.8, 0.8, 0.8, 1}
            love.graphics.setColor(color)
            love.graphics.setFont(love.graphics.newFont(12))
            love.graphics.print(string.format("%s: %d pts", player.name,
                                              player.score), playerListX, y)
        end
    end

    -- Draw valid moves indicator
    if self.grid then
        local validMoves = #self.grid.validPairs
        love.graphics.setColor(0.7, 0.7, 0.7, 1)
        love.graphics.setFont(love.graphics.newFont(12))
        love.graphics.printf("Valid moves: " .. validMoves,
                             screenWidth / 2 - 50, screenHeight - 30, 100,
                             "center")
    end
end

function gameplay:drawGameOver()
    local screenWidth, screenHeight = love.graphics.getDimensions()

    -- Draw overlay
    love.graphics.setColor(0, 0, 0, 0.7)
    love.graphics.rectangle("fill", 0, 0, screenWidth, screenHeight)

    -- Draw game over panel
    local panelX = (screenWidth - 400) / 2
    local panelY = (screenHeight - 200) / 2

    love.graphics.setColor(1, 1, 1, 1)
    self.gameOverSVG:draw(panelX, panelY)

    -- Game over title
    love.graphics.setFont(love.graphics.newFont(24))
    love.graphics.setColor(1, 1, 1, 1)
    local title = "Game Over!"
    local titleWidth = love.graphics.getFont():getWidth(title)
    love.graphics.print(title, panelX + 200 - titleWidth / 2, panelY + 20)

    -- Show results
    love.graphics.setFont(love.graphics.newFont(16))
    if self.gameMode == 'single' then
        local finalScore = "Final Score: " .. self.currentPlayer.score
        local scoreWidth = love.graphics.getFont():getWidth(finalScore)
        love.graphics.print(finalScore, panelX + 200 - scoreWidth / 2,
                            panelY + 60)

        local timeFormatted = self.mainTimer:getFormattedTime().formatted
        local timeText = "Time: " .. timeFormatted
        local timeWidth = love.graphics.getFont():getWidth(timeText)
        love.graphics.print(timeText, panelX + 200 - timeWidth / 2, panelY + 85)
    else
        -- Show multiplayer results
        if self.winner then
            local winText = self.winner.name .. " Wins!"
            local winWidth = love.graphics.getFont():getWidth(winText)
            love.graphics.setColor(0.3, 0.8, 0.3, 1)
            love.graphics.print(winText, panelX + 200 - winWidth / 2,
                                panelY + 55)

            love.graphics.setColor(1, 1, 1, 1)
            love.graphics.setFont(love.graphics.newFont(12))
            local scoreText = "Score: " .. self.winner.score
            local scoreWidth = love.graphics.getFont():getWidth(scoreText)
            love.graphics.print(scoreText, panelX + 200 - scoreWidth / 2,
                                panelY + 80)
        end
    end

    -- Draw buttons
    local restartX = panelX + 60
    local menuX = panelX + 220
    local buttonY = panelY + 140

    -- Restart button
    local restartSVG = self.gameOverButtons.restart.hover and
                           self.smallButtonHoverSVG or self.smallButtonSVG
    love.graphics.setColor(1, 1, 1, 1)
    restartSVG:draw(restartX, buttonY)

    love.graphics.setFont(love.graphics.newFont(14))
    local restartText = "Restart"
    local restartWidth = love.graphics.getFont():getWidth(restartText)
    love.graphics.print(restartText, restartX + 60 - restartWidth / 2,
                        buttonY + 13)

    -- Menu button
    local menuSVG =
        self.gameOverButtons.menu.hover and self.smallButtonHoverSVG or
            self.smallButtonSVG
    menuSVG:draw(menuX, buttonY)

    local menuText = "Menu"
    local menuWidth = love.graphics.getFont():getWidth(menuText)
    love.graphics.print(menuText, menuX + 60 - menuWidth / 2, buttonY + 13)
end

function gameplay:drawPause()
    local screenWidth, screenHeight = love.graphics.getDimensions()

    -- Draw overlay
    love.graphics.setColor(0, 0, 0, 0.5)
    love.graphics.rectangle("fill", 0, 0, screenWidth, screenHeight)

    -- Draw pause text
    love.graphics.setFont(love.graphics.newFont(36))
    love.graphics.setColor(1, 1, 1, 1)
    local pauseText = "PAUSED"
    local textWidth = love.graphics.getFont():getWidth(pauseText)
    love.graphics.print(pauseText, screenWidth / 2 - textWidth / 2,
                        screenHeight / 2 - 40)

    love.graphics.setFont(love.graphics.newFont(16))
    local instructionText = "Press P to resume"
    local instrWidth = love.graphics.getFont():getWidth(instructionText)
    love.graphics.print(instructionText, screenWidth, screenHeight / 2 + 20)
end

function gameplay:mousepressed(x, y, button)
    if self.isGameOver then
        -- Handle game over screen clicks
        local screenWidth, screenHeight = love.graphics.getDimensions()
        local panelX = (screenWidth - 400) / 2
        local panelY = (screenHeight - 200) / 2

        local restartX = panelX + 60
        local menuX = panelX + 220
        local buttonY = panelY + 140

        if button == 1 then
            -- Restart button
            if x >= restartX and x <= restartX + 120 and y >= buttonY and y <=
                buttonY + 40 then
                -- In single player, just restart. In multiplayer, this is more complex.
                -- For now, let's just allow single player restart.
                if self.gameMode == 'single' then
                    self:enter() -- Restart game
                end
                return
            end

            -- Menu button
            if x >= menuX and x <= menuX + 120 and y >= buttonY and y <= buttonY +
                40 then
                local menuState = require('states.menu')
                gamestateHump.switch(menuState)
                return
            end
        end
    elseif not self.isPaused and self.grid and self.gameStarted then
        -- Handle grid clicks
        local moveMade, row, col = self.grid:mousepressed(x, y, button)
        if moveMade and self.isConnected then
            -- If a successful move was made (pair cleared), broadcast it
            -- The grid:mousepressed needs to return more info for this.
            -- Let's assume for now any click is a potential move to be shared.
            -- A better approach is to only send confirmed pair clears.
            if row and col then
                local message = "SELECT:" .. row .. ":" .. col
                if self.isHost then
                    net.broadcast(message)
                else
                    net.send(message)
                end
            end
        end
    end
end

function gameplay:keypressed(key)
    if key == "escape" then
        local menuState = require('states.menu')
        gamestateHump.switch(menuState)
    elseif key == "p" then
        self.isPaused = not self.isPaused
        if self.isPaused then
            self.mainTimer:pause()
        else
            self.mainTimer:resume()
        end
    elseif key == "r" and self.isGameOver and self.gameMode == 'single' then
        self:enter() -- Restart game
    elseif key == "m" and self.isGameOver then
        local menuState = require('states.menu')
        gamestateHump.switch(menuState)
    end
end

function gameplay:resize(w, h) if self.grid then self.grid:resize(w, h) end end

function gameplay:leave()
    utils.printWithPath("Leaving gameplay state...")
    -- Clean up network callbacks and timers to prevent memory leaks or errors
    net.onReceive = nil
    if self.mainTimer then self.mainTimer:stop() end
end

-- Networking Functions
function gameplay:handleNetworkMessage(message, senderId)
    utils.printWithPath("Received message: " .. message)
    -- Simple message protocol: COMMAND:DATA1:DATA2:...
    local parts = {}
    for part in message:gmatch("([^:]+)") do table.insert(parts, part) end
    local command = parts[1]

    if not command then return end

    if command == "SELECT" then
        local row, col = tonumber(parts[2]), tonumber(parts[3])
        if row and col and self.grid then
            -- If this is the host, re-broadcast to all other clients
            if self.isHost then net.broadcast(message) end
            -- Apply the move locally
            self.grid:selectCell(row, col)
        end
    elseif command == "GAME_STATE" then
        -- Only clients should accept a full game state update
        if not self.isHost and self.grid then
            local gridData = parts[2]
            -- Deserialize grid data (a more robust serialization like JSON is better)
            -- For now, let's assume it's a simple string of numbers
            self.grid:loadFromString(gridData)
        end
    elseif command == "SCORE_UPDATE" then
        local playerName, playerScore = parts[2], tonumber(parts[3])
        if playerName and playerScore then
            for i, player in ipairs(self.players) do
                if player.name == playerName then
                    player.score = playerScore
                    break
                end
            end
        end
    elseif command == "GAME_OVER" then
        self.isGameOver = true
        self.winner = {name = parts[2], score = tonumber(parts[3])}
        if self.mainTimer then self.mainTimer:stop() end
    end
end

function gameplay:broadcastGameState()
    if not self.isHost or not self.grid then return end

    -- A more robust serialization method (like JSON) would be better here.
    -- For now, we'll create a simple string representation of the grid.
    local gridString = self.grid:serializeToString()
    net.broadcast("GAME_STATE:" .. gridString)
end

return gameplay
