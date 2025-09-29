-- src/game/grid.lua
local tove = require("tove")
local Grid = {}
Grid.__index = Grid

function Grid.new(cols, screenWidth, screenHeight)
    local self = setmetatable({}, Grid)
    self.cols = cols or 6
    self.font = nil

    self:recalculateDimensions(screenWidth, screenHeight)

    self.cells = {}
    self.selectedCells = {}
    self.validPairs = {}
    self.score = 0
    self:initializeGrid()
    self:createSVGElements()
    return self
end

function Grid:recalculateDimensions(newWidth, newHeight)
    self.screenWidth = newWidth
    self.screenHeight = newHeight
    local gridPadding = 40
    local availableWidth = newWidth - (gridPadding * 2)
    local availableHeight = newHeight - 120

    self.cellSize = math.floor(math.min(availableWidth / self.cols, 80))
    self.gridWidth = self.cellSize * self.cols
    self.rows = math.floor(availableHeight / self.cellSize)
    self.gridHeight = self.cellSize * self.rows

    -- Using math.floor here is still good practice for consistency
    self.offsetX = math.floor((newWidth - self.gridWidth) / 2)
    self.offsetY = 100
end

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

function Grid:createSVGElements()
    self.font = love.graphics.newFont(math.floor(self.cellSize * 0.5))
    local svgScale = self.cellSize

    self.cellSVG = tove.newGraphics(
                       [[<svg width="50" height="50" xmlns="http://www.w3.org/2000/svg"><rect x="2" y="2" width="46" height="46" rx="6" ry="6" fill="#2c3e50" stroke="#34495e" stroke-width="2"/></svg>]],
                       svgScale)
    self.selectedCellSVG = tove.newGraphics(
                               [[<svg width="50" height="50" xmlns="http://www.w3.org/2000/svg"><rect x="2" y="2" width="46" height="46" rx="6" ry="6" fill="#3498db" stroke="#2980b9" stroke-width="3"/></svg>]],
                               svgScale)
    self.emptyCellSVG = tove.newGraphics(
                            [[<svg width="50" height="50" xmlns="http://www.w3.org/2000/svg"><rect x="2" y="2" width="46" height="46" rx="6" ry="6" fill="#1a252f" stroke="#2c3e50" stroke-width="1" stroke-dasharray="3,3"/></svg>]],
                            svgScale)
end

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

---
--- DRAW FUNCTION REWRITTEN TO USE CELL CENTERS
---
function Grid:draw()
    love.graphics.setColor(1, 1, 1, 1)
    local halfCell = self.cellSize / 2

    -- PASS 1: Draw all the SVG cell backgrounds.
    for row = 1, self.rows do
        for col = 1, self.cols do
            -- Calculate the TOP-LEFT corner of the cell
            local x = self.offsetX + (col - 1) * self.cellSize
            local y = self.offsetY + (row - 1) * self.cellSize

            local centerX = x + halfCell
            local centerY = y + halfCell

            local cell = self.cells[row][col]
            local svgToDraw = cell.isEmpty and self.emptyCellSVG or
                                  (cell.isSelected and self.selectedCellSVG or
                                      self.cellSVG)

            -- Draw the SVG at the cell's CENTER
            svgToDraw:draw(centerX, centerY)
        end
    end

    -- PASS 2: Draw all the numbers on top.
    love.graphics.setFont(self.font)
    for row = 1, self.rows do
        for col = 1, self.cols do
            local cell = self.cells[row][col]
            if not cell.isEmpty then
                -- Calculate the TOP-LEFT corner of the cell again for text calculation
                local x = self.offsetX + (col - 1) * self.cellSize
                local y = self.offsetY + (row - 1) * self.cellSize

                local text = tostring(cell.value)

                local textWidth = self.font:getWidth(text)
                local textHeight = self.font:getHeight()
                local textX = x + (self.cellSize - textWidth) / 2
                local textY = y + (self.cellSize - textHeight) / 2

                love.graphics.print(text, textX, textY)
            end
        end
    end
end

-- All other functions remain the same as they deal with logical grid, not drawing.
function Grid:isAdjacent(row1, col1, row2, col2)
    local rowDiff = math.abs(row1 - row2);
    local colDiff = math.abs(col1 - col2);
    return (rowDiff == 1 and colDiff == 0) or (rowDiff == 0 and colDiff == 1)
end
function Grid:selectCell(row, col)
    if not self.cells[row] or not self.cells[row][col] or
        self.cells[row][col].isEmpty then return false, "Invalid cell" end
    local cell = self.cells[row][col];
    if cell.isSelected then
        cell.isSelected = false;
        for i = #self.selectedCells, 1, -1 do
            if self.selectedCells[i].row == row and self.selectedCells[i].col ==
                col then
                table.remove(self.selectedCells, i);
                break
            end
        end
        return true, "Deselected", row, col
    end
    if #self.selectedCells >= 2 then return false, "Too many selected" end
    cell.isSelected = true;
    table.insert(self.selectedCells, {row = row, col = col});
    if #self.selectedCells == 2 then
        local success, reason = self:checkAndClearPair();
        if not success then
            self:clearSelection();
            return false, reason, row, col
        else
            return true, "Pair cleared", row, col
        end
    end
    return true, "Selected", row, col
end
function Grid:checkAndClearPair()
    if #self.selectedCells ~= 2 then return false, "Not two cells" end
    local cell1Pos, cell2Pos = self.selectedCells[1], self.selectedCells[2];
    local cell1, cell2 = self.cells[cell1Pos.row][cell1Pos.col],
                         self.cells[cell2Pos.row][cell2Pos.col];
    if self:isAdjacent(cell1Pos.row, cell1Pos.col, cell2Pos.row, cell2Pos.col) and
        (cell1.value + cell2.value) == 10 then
        cell1.isEmpty, cell1.isSelected = true, false;
        cell2.isEmpty, cell2.isSelected = true, false;
        self.score = self.score + 20;
        self.selectedCells = {};
        self:updateValidPairs();
        return true, "Success"
    else
        return false, "Invalid pair"
    end
end
function Grid:clearSelection()
    for _, cellPos in ipairs(self.selectedCells) do
        if self.cells[cellPos.row] and self.cells[cellPos.row][cellPos.col] then
            self.cells[cellPos.row][cellPos.col].isSelected = false
        end
    end
    self.selectedCells = {}
end
function Grid:updateValidPairs()
    self.validPairs = {};
    for row = 1, self.rows do
        for col = 1, self.cols do
            if not self.cells[row][col].isEmpty then
                local value = self.cells[row][col].value;
                local adjacents = {
                    {row - 1, col}, {row + 1, col}, {row, col - 1},
                    {row, col + 1}
                };
                for _, adj in ipairs(adjacents) do
                    local adjRow, adjCol = adj[1], adj[2];
                    if adjRow >= 1 and adjRow <= self.rows and adjCol >= 1 and
                        adjCol <= self.cols and
                        not self.cells[adjRow][adjCol].isEmpty then
                        if value + self.cells[adjRow][adjCol].value == 10 then
                            table.insert(self.validPairs,
                                         {{row, col}, {adjRow, adjCol}})
                        end
                    end
                end
            end
        end
    end
end
function Grid:hasValidMoves() return #self.validPairs > 0 end
function Grid:getScore() return self.score end
function Grid:mousepressed(x, y, button)
    if button == 1 then
        local row, col = self:getCellAt(x, y);
        if row and col then
            local success, reason, r, c = self:selectCell(row, col);
            return success, r or row, c or col
        end
    end
    return false
end
function Grid:resize(newWidth, newHeight)
    self:recalculateDimensions(newWidth, newHeight);
    local newRows = self.rows;
    local oldRows = #self.cells;
    if newRows ~= oldRows then
        if newRows > oldRows then
            for row = oldRows + 1, newRows do
                self.cells[row] = {};
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
    end
    self:createSVGElements();
    self:updateValidPairs()
end
function Grid:serializeToString()
    local t = {};
    for row = 1, self.rows do
        for col = 1, self.cols do
            local cell = self.cells[row][col];
            if cell.isEmpty then
                table.insert(t, "0")
            else
                table.insert(t, tostring(cell.value))
            end
        end
    end
    return table.concat(t, "")
end
function Grid:loadFromString(dataString)
    if not dataString then return end
    local index = 1;
    for row = 1, self.rows do
        for col = 1, self.cols do
            if self.cells[row] and self.cells[row][col] then
                local char = dataString:sub(index, index);
                local value = tonumber(char);
                if value == 0 then
                    self.cells[row][col].isEmpty, self.cells[row][col].value =
                        true, 0
                else
                    self.cells[row][col].isEmpty, self.cells[row][col].value =
                        false, value
                end
                self.cells[row][col].isSelected = false
            end
            index = index + 1
        end
    end
    self:updateValidPairs();
    local clearedCells = 0;
    for row = 1, self.rows do
        for col = 1, self.cols do
            if self.cells[row][col].isEmpty then
                clearedCells = clearedCells + 1
            end
        end
    end
    self.score = clearedCells * 10
end

return Grid
