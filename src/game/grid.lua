-- src/game/grid.lua
local Theme = require("src.game.theme")
local tove = require("tove")

-- Configuration Constants
local CONFIG = {
    GRID_PADDING = 40,
    GRID_TOP_OFFSET = 100,
    CELL_SIZE_CAP = 40,
    FONT_SCALE = 0.5
}

local Grid = {}
Grid.__index = Grid

-- Constructor
function Grid.new(cols, screenWidth, screenHeight)
    local self = setmetatable({}, Grid)
    self.cols = cols or 6
    self.score = 0
    self.cells = {}
    self.selectedCells = {}
    self.validPairs = {}

    self.timeLimit = 60 -- الوقت الكلي بالثواني (مثلاً دقيقة)
    self.timeElapsed = 0 -- الوقت الذي مر من بداية اللعبة

    self:recalculateDimensions(screenWidth, screenHeight)
    self:initializeGrid()
    self.theme = Theme.new()
    self.themeButton = {x = 20, y = 20, width = 120, height = 40}
    self:createSVGElements()

    return self
end

-- Dimension Calculations
function Grid:recalculateDimensions(width, height)
    local padding = CONFIG.GRID_PADDING
    local topOffset = CONFIG.GRID_TOP_OFFSET

    local availableWidth = width - (padding * 2)
    local availableHeight = height - topOffset - padding

    self.cellSize = math.floor(math.min(availableWidth / self.cols,
                                        CONFIG.CELL_SIZE_CAP))
    self.gridWidth = self.cellSize * self.cols
    self.rows = math.floor(availableHeight / self.cellSize)
    self.gridHeight = self.cellSize * self.rows

    self.offsetX = math.floor((width - self.gridWidth) / 2)
    self.offsetY = topOffset
end

-- Grid Initialization
function Grid:initializeGrid()
    for row = 1, self.rows do
        self.cells[row] = {}
        for col = 1, self.cols do
            self.cells[row][col] = {
                value = love.math.random(1, 9),
                isEmpty = false,
                isSelected = false
            }
        end
    end
    self:updateValidPairs()
end

-- SVG Initialization
function Grid:createSVGElements()
    self.font = love.graphics.newFont(math.floor(self.cellSize * 0.5))
    local svgScale = self.cellSize
    local themeColors = self.theme:get()

    local function makeRectSVG(cellData)
        local dash = cellData.dash and 'stroke-dasharray="3,3"' or ''
        return string.format(
                   [[<svg width="50" height="50" xmlns="http://www.w3.org/2000/svg">
                <rect x="2" y="2" width="46" height="46" rx="6" ry="6"
                      fill="%s" stroke="%s" stroke-width="2" %s/>
              </svg>]], cellData.fill, cellData.stroke, dash)
    end

    self.cellSVG = tove.newGraphics(makeRectSVG(themeColors.cell), svgScale)
    self.selectedCellSVG = tove.newGraphics(
                               makeRectSVG(themeColors.selectedCell), svgScale)
    self.emptyCellSVG = tove.newGraphics(makeRectSVG(themeColors.emptyCell),
                                         svgScale)
end

function Grid:toggleTheme()
    self.theme:switch()
    self:createSVGElements()
end

function Grid:drawThemeButton()
    local themeData = self.theme:get()
    local themeName = themeData.name == "light" and "Dark Mode" or "Light Mode"

    love.graphics.setColor(themeData.buttonBackground or {0.9, 0.9, 0.9, 1})
    love.graphics.rectangle("fill", self.themeButton.x, self.themeButton.y,
                            self.themeButton.width, self.themeButton.height, 8,
                            8)

    love.graphics.setColor(themeData.buttonText or {0.2, 0.2, 0.2, 1})
    love.graphics.setFont(love.graphics.newFont(14))
    love.graphics.printf(themeName, self.themeButton.x, self.themeButton.y + 10,
                         self.themeButton.width, "center")
end

function Grid:update(dt)
    self.timeElapsed = self.timeElapsed + dt
    if self.timeElapsed > self.timeLimit then
        self.timeElapsed = self.timeLimit
        -- ممكن تضيف هنا كود نهاية اللعبة أو أي سلوك عند انتهاء الوقت
    end
end

function Grid:isInsideThemeButton(x, y)
    local b = self.themeButton
    return x >= b.x and x <= b.x + b.width and y >= b.y and y <= b.y + b.height
end

-- Drawing Function
function Grid:draw()
    local theme = self.theme:get()

    -- ارسم الخلفية حسب الثيم
    love.graphics.clear(theme.background)

    love.graphics.setColor(1, 1, 1, 1)
    local halfCell = self.cellSize / 2

    -- رسم الخلايا
    for row = 1, self.rows do
        for col = 1, self.cols do
            local x = self.offsetX + (col - 1) * self.cellSize
            local y = self.offsetY + (row - 1) * self.cellSize
            local centerX = x + halfCell
            local centerY = y + halfCell

            local cell = self.cells[row][col]
            local svgToDraw = cell.isEmpty and self.emptyCellSVG or
                                  (cell.isSelected and self.selectedCellSVG or
                                      self.cellSVG)

            svgToDraw:draw(centerX, centerY)
        end
    end

    -- رسم الأرقام
    love.graphics.setFont(self.font)
    love.graphics.setColor(theme.textColor)

    for row = 1, self.rows do
        for col = 1, self.cols do
            local cell = self.cells[row][col]
            if not cell.isEmpty then
                local x = self.offsetX + (col - 1) * self.cellSize
                local y = self.offsetY + (row - 1) * self.cellSize
                local text = tostring(cell.value)
                local textX = x + (self.cellSize - self.font:getWidth(text)) / 2
                local textY = y + (self.cellSize - self.font:getHeight()) / 2
                love.graphics.print(text, textX, textY)
            end
        end
    end

    -- رسم زر تغيير الثيم
    self:drawThemeButton()

    -- الآن نرسم لوحة المعلومات الجرافيكية (Score, Time Left, Moves Left)
    local infoX, infoY = 20, 70
    local boxWidth, boxHeight = 150, 40
    local padding = 10
    local spacing = 10
    local font = love.graphics.newFont(18)
    love.graphics.setFont(font)

    local function drawInfoBox(x, y, label, value, color)
        -- صندوق خلفية دائري بزوايا منحنية
        love.graphics.setColor(color[1], color[2], color[3], color[4] or 1)
        love.graphics.rectangle("fill", x, y, boxWidth, boxHeight, 10, 10)

        -- نص العنوان
        love.graphics.setColor(1, 1, 1, 0.7)
        love.graphics.printf(label, x + padding, y + 5, boxWidth - 2 * padding,
                             "left")

        -- النص الرئيسي (القيمة)
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.printf(value, x + padding, y + 20, boxWidth - 2 * padding,
                             "left")
    end

    -- قيم المعلومات
    local timeLeft = math.max(0, math.floor(self.timeLimit - self.timeElapsed))
    local scoreColor = {0.2, 0.6, 0.86, 1} -- أزرق
    local timeColor = {0.9, 0.4, 0.3, 1} -- أحمر برتقالي
    local movesColor = {0.3, 0.8, 0.4, 1} -- أخضر

    drawInfoBox(infoX, infoY, "Score", tostring(self.score), scoreColor)
    drawInfoBox(infoX + boxWidth + spacing, infoY, "Time Left", timeLeft .. "s",
                timeColor)
    drawInfoBox(infoX + (boxWidth + spacing) * 2, infoY, "Moves Left",
                tostring(#self.validPairs), movesColor)

    -- عدل اللون للرجوع للرسومات الأخرى لو احتجت
    love.graphics.setColor(1, 1, 1, 1)
end

-- Input Handling
function Grid:getCellAt(x, y)
    if x < self.offsetX or y < self.offsetY or x > self.offsetX + self.gridWidth or
        y > self.offsetY + self.gridHeight then return nil, nil end

    local col = math.floor((x - self.offsetX) / self.cellSize) + 1
    local row = math.floor((y - self.offsetY) / self.cellSize) + 1

    if col >= 1 and col <= self.cols and row >= 1 and row <= self.rows then
        return row, col
    end

    return nil, nil
end

function Grid:mousepressed(x, y, button)
    if button == 1 then
        -- Check if theme button is clicked
        if self:isInsideThemeButton(x, y) then
            self:toggleTheme()
            return true
        end

        -- Normal cell selection
        local row, col = self:getCellAt(x, y)
        if row and col then
            local success, reason, r, c = self:selectCell(row, col)
            return success, r or row, c or col
        end
    end
    return false
end

-- Cell Interaction
function Grid:isAdjacent(r1, c1, r2, c2)
    return (math.abs(r1 - r2) == 1 and c1 == c2) or
               (r1 == r2 and math.abs(c1 - c2) == 1)
end

function Grid:selectCell(row, col)
    local cell = self.cells[row] and self.cells[row][col]
    if not cell or cell.isEmpty then return false, "Invalid cell" end

    if cell.isSelected then
        cell.isSelected = false
        for i = #self.selectedCells, 1, -1 do
            if self.selectedCells[i].row == row and self.selectedCells[i].col ==
                col then
                table.remove(self.selectedCells, i)
                break
            end
        end
        return true, "Deselected", row, col
    end

    if #self.selectedCells >= 2 then return false, "Too many selected" end

    cell.isSelected = true
    table.insert(self.selectedCells, {row = row, col = col})

    if #self.selectedCells == 2 then
        local success, reason = self:checkAndClearPair()
        if not success then
            self:clearSelection()
            return false, reason, row, col
        end
        return true, "Pair cleared", row, col
    end

    return true, "Selected", row, col
end

function Grid:checkAndClearPair()
    if #self.selectedCells ~= 2 then return false, "Not two cells" end

    local a, b = self.selectedCells[1], self.selectedCells[2]
    local cell1 = self.cells[a.row][a.col]
    local cell2 = self.cells[b.row][b.col]

    if self:isAdjacent(a.row, a.col, b.row, b.col) and
        (cell1.value + cell2.value == 10) then
        cell1.isEmpty, cell1.isSelected = true, false
        cell2.isEmpty, cell2.isSelected = true, false
        self.score = self.score + 20
        self.selectedCells = {}
        self:updateValidPairs()
        return true, "Success"
    else
        return false, "Invalid pair"
    end
end

function Grid:clearSelection()
    for _, cell in ipairs(self.selectedCells) do
        if self.cells[cell.row] and self.cells[cell.row][cell.col] then
            self.cells[cell.row][cell.col].isSelected = false
        end
    end
    self.selectedCells = {}
end

-- Valid Pair Check
function Grid:updateValidPairs()
    self.validPairs = {}
    for row = 1, self.rows do
        for col = 1, self.cols do
            local cell = self.cells[row][col]
            if not cell.isEmpty then
                local value = cell.value
                local adjacentOffsets = {{-1, 0}, {1, 0}, {0, -1}, {0, 1}}

                for _, offset in ipairs(adjacentOffsets) do
                    local r, c = row + offset[1], col + offset[2]
                    if r >= 1 and r <= self.rows and c >= 1 and c <= self.cols then
                        local neighbor = self.cells[r][c]
                        if not neighbor.isEmpty and value + neighbor.value == 10 then
                            table.insert(self.validPairs, {{row, col}, {r, c}})
                        end
                    end
                end
            end
        end
    end
end

function Grid:hasValidMoves() return #self.validPairs > 0 end

-- Resizing Logic
function Grid:resize(newWidth, newHeight)
    self:recalculateDimensions(newWidth, newHeight)
    local newRows = self.rows
    local oldRows = #self.cells

    if newRows > oldRows then
        for row = oldRows + 1, newRows do
            self.cells[row] = {}
            for col = 1, self.cols do
                self.cells[row][col] = {
                    value = love.math.random(1, 9),
                    isEmpty = false,
                    isSelected = false
                }
            end
        end
    else
        for row = newRows + 1, oldRows do self.cells[row] = nil end
    end

    self:createSVGElements()
    self:updateValidPairs()
end

-- Serialization
function Grid:serializeToString()
    local output = {}
    for row = 1, self.rows do
        for col = 1, self.cols do
            local val = self.cells[row][col].isEmpty and "0" or
                            tostring(self.cells[row][col].value)
            table.insert(output, val)
        end
    end
    return table.concat(output)
end

function Grid:loadFromString(data)
    if not data then return end
    local index = 1
    local cleared = 0

    for row = 1, self.rows do
        for col = 1, self.cols do
            local char = data:sub(index, index)
            local val = tonumber(char) or 0
            local cell = self.cells[row][col]
            cell.value = val
            cell.isEmpty = val == 0
            cell.isSelected = false
            if cell.isEmpty then cleared = cleared + 1 end
            index = index + 1
        end
    end

    self.score = cleared * 10
    self:updateValidPairs()
end

function Grid:getScore() return self.score end

return Grid
