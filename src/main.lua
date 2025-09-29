-- src/main.lua
local projectRoot = love.filesystem.getSourceBaseDirectory()
if not projectRoot:match("/$") then projectRoot = projectRoot .. "/" end

local paths = {projectRoot .. "lib/?.lua", projectRoot .. "lib/?/init.lua"}
package.path = package.path .. ";" .. table.concat(paths, ";")

local cpaths = {projectRoot .. "lib/?.dll", projectRoot .. "lib/?/?.dll"}
package.cpath = package.cpath .. ";" .. table.concat(cpaths, ";")

local utils = require('utils')
local tove = require("tove")
local classHump = require('hump.class')
local gamestateHump = require('hump.gamestate')
local signalHump = require('hump.signal')
local timerHump = require('hump.timer')
local vectorHump = require('hump.vector')
local vectorLightHump = require('hump.vector-light')

local menuState = require('states.menu')
local gameplayState = require('states.gameplay')

utils.printWithPath("🔃 Start downloading Love2D...")

utils.printWithPath("✅ TÖVE has been required successfully")

function love.load()
    love.window.setTitle("Numbers Game - LÖVE + TÖVE")
    love.window.setMode(1024, 768,
                        {resizable = true, minwidth = 640, minheight = 480})
    -- start at menu
    gamestateHump.registerEvents()
    gamestateHump.switch(menuState)
end

function love.keypressed(key)
    utils.printWithPath("The key was pressed: " .. key)
    if key == "escape" then
        utils.printWithPath("Closing the game...")
        love.event.quit()
    end
end

function love.quit()
    utils.printWithPath("The game is closed")
    return false
end

utils.printWithPath("✅ All functions have been loaded successfully")
