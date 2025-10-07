local Theme = {}
Theme.__index = Theme

function Theme.new()
    local self = setmetatable({}, Theme)
    self.current = "light"
    self.themes = {
        light = {
            name = "light",
            background = {1, 1, 1},
            textColor = {0, 0, 0},
            cell = {fill = "#ffffff", stroke = "#cccccc"},
            selectedCell = {fill = "#aaddff", stroke = "#3399ff"},
            emptyCell = {fill = "#eeeeee", stroke = "#bbbbbb"},
            buttonBackground = {0.9, 0.9, 0.9, 1},
            buttonText = {0.1, 0.1, 0.1, 1}
        },
        dark = {
            name = "dark",
            background = {0.1, 0.1, 0.1},
            textColor = {1, 1, 1},
            cell = {fill = "#2c3e50", stroke = "#34495e"},
            selectedCell = {fill = "#3498db", stroke = "#2980b9"},
            emptyCell = {fill = "#1a252f", stroke = "#2c3e50"},
            buttonBackground = {0.2, 0.2, 0.2, 1},
            buttonText = {0.9, 0.9, 0.9, 1}
        }
    }
    return self
end

function Theme:get() return self.themes[self.current] end

function Theme:switch()
    if self.current == "light" then
        self.current = "dark"
    else
        self.current = "light"
    end
end

return Theme
