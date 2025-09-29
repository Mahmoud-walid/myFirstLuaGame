-- src/systems/timer.lua
local Timer = {}
Timer.__index = Timer

function Timer.new(mode, duration)
    local self = setmetatable({}, Timer)

    self.mode = mode or "countup" -- "countup" or "countdown"
    self.duration = duration or 0 -- For countdown mode
    self.currentTime = mode == "countdown" and duration or 0
    self.isRunning = false
    self.isPaused = false
    self.startTime = 0
    self.pausedTime = 0

    -- Callbacks
    self.onFinished = nil
    self.onTick = nil
    self.onWarning = nil -- Called when time is low

    -- Warning settings
    self.warningThreshold = 10 -- seconds
    self.warningTriggered = false

    return self
end

function Timer:start()
    if not self.isRunning then
        self.isRunning = true
        self.isPaused = false
        self.startTime = love.timer.getTime() - self.pausedTime

        if self.mode == "countdown" and self.currentTime <= 0 then
            self.currentTime = self.duration
        end
    end
end

function Timer:pause()
    if self.isRunning and not self.isPaused then
        self.isPaused = true
        self.pausedTime = love.timer.getTime() - self.startTime
    end
end

function Timer:resume()
    if self.isRunning and self.isPaused then
        self.isPaused = false
        self.startTime = love.timer.getTime() - self.pausedTime
    end
end

function Timer:stop()
    self.isRunning = false
    self.isPaused = false
    self.pausedTime = 0
end

function Timer:reset()
    self:stop()
    self.currentTime = self.mode == "countdown" and self.duration or 0
    self.warningTriggered = false
    self.pausedTime = 0
end

function Timer:update(dt)
    if not self.isRunning or self.isPaused then return end

    local realTime = love.timer.getTime() - self.startTime

    if self.mode == "countup" then
        self.currentTime = realTime
    elseif self.mode == "countdown" then
        self.currentTime = self.duration - realTime

        -- Check if time is up
        if self.currentTime <= 0 then
            self.currentTime = 0
            self:stop()
            if self.onFinished then self.onFinished() end
            return
        end

        -- Check for warning threshold
        if not self.warningTriggered and self.currentTime <=
            self.warningThreshold then
            self.warningTriggered = true
            if self.onWarning then self.onWarning(self.currentTime) end
        end
    end

    -- Call tick callback
    if self.onTick then self.onTick(self.currentTime) end
end

function Timer:getTime() return self.currentTime end

function Timer:getFormattedTime()
    local time = math.max(0, self.currentTime)
    local minutes = math.floor(time / 60)
    local seconds = math.floor(time % 60)
    local milliseconds = math.floor((time % 1) * 100)

    return {
        minutes = minutes,
        seconds = seconds,
        milliseconds = milliseconds,
        formatted = string.format("%02d:%02d", minutes, seconds),
        formattedWithMs = string.format("%02d:%02d.%02d", minutes, seconds,
                                        milliseconds)
    }
end

function Timer:getRemainingTime()
    if self.mode == "countdown" then
        return math.max(0, self.currentTime)
    else
        return 0
    end
end

function Timer:getElapsedTime()
    if self.mode == "countup" then
        return self.currentTime
    else
        return self.duration - self.currentTime
    end
end

function Timer:getProgress()
    if self.mode == "countdown" then
        return 1 - (self.currentTime / self.duration)
    else
        return 0 -- Countup timers don't have progress
    end
end

function Timer:isFinished()
    return self.mode == "countdown" and self.currentTime <= 0
end

function Timer:isWarningTime()
    return self.mode == "countdown" and self.currentTime <=
               self.warningThreshold and self.currentTime > 0
end

function Timer:addTime(seconds)
    if self.mode == "countdown" then
        self.currentTime = self.currentTime + seconds
        self.currentTime = math.min(self.currentTime, self.duration)
    end
end

function Timer:subtractTime(seconds)
    if self.mode == "countdown" then
        self.currentTime = self.currentTime - seconds
        self.currentTime = math.max(self.currentTime, 0)

        if self.currentTime <= 0 then
            self:stop()
            if self.onFinished then self.onFinished() end
        end
    end
end

function Timer:setDuration(duration)
    self.duration = duration
    if self.mode == "countdown" and not self.isRunning then
        self.currentTime = duration
    end
end

function Timer:setOnFinished(callback) self.onFinished = callback end

function Timer:setOnTick(callback) self.onTick = callback end

function Timer:setOnWarning(callback) self.onWarning = callback end

function Timer:setWarningThreshold(threshold)
    self.warningThreshold = threshold
    self.warningTriggered = false
end

-- Static methods for creating common timer types
function Timer.createGameTimer(duration)
    local timer = Timer.new("countdown", duration or 60)
    return timer
end

function Timer.createStopwatch()
    local timer = Timer.new("countup", 0)
    return timer
end

function Timer.createMultiplayerTimer(duration)
    local timer = Timer.new("countdown", duration or 120)
    timer:setWarningThreshold(30) -- 30 second warning
    return timer
end

-- Timer Manager for handling multiple timers
local TimerManager = {}
TimerManager.__index = TimerManager

function TimerManager.new()
    local self = setmetatable({}, TimerManager)
    self.timers = {}
    return self
end

function TimerManager:addTimer(name, timer) self.timers[name] = timer end

function TimerManager:getTimer(name) return self.timers[name] end

function TimerManager:removeTimer(name) self.timers[name] = nil end

function TimerManager:update(dt)
    for name, timer in pairs(self.timers) do timer:update(dt) end
end

function TimerManager:startAll()
    for name, timer in pairs(self.timers) do timer:start() end
end

function TimerManager:pauseAll()
    for name, timer in pairs(self.timers) do timer:pause() end
end

function TimerManager:resumeAll()
    for name, timer in pairs(self.timers) do timer:resume() end
end

function TimerManager:stopAll()
    for name, timer in pairs(self.timers) do timer:stop() end
end

function TimerManager:resetAll()
    for name, timer in pairs(self.timers) do timer:reset() end
end

-- Export both Timer and TimerManager
return {Timer = Timer, TimerManager = TimerManager}
