local M = {}

-- to use it, dot this in below
-- suit.Button("Styled Button", {draw = customButtonDraw}, suit.layout:row(200, 40))

function M.customButtonDraw(state, text, x, y, w, h)
    -- bg color
    if state == "hot" then
        love.graphics.setColor(0.4, 0.4, 0.9)
    elseif state == "active" then
        love.graphics.setColor(0.2, 0.2, 0.6)
    else
        love.graphics.setColor(0.3, 0.3, 0.3)
    end
    love.graphics.rectangle("fill", x, y, w, h, 4, 4)

    -- text
    love.graphics.setColor(1, 1, 1)
    love.graphics.printf(text, x, y + h / 2 - 6, w, "center")
end

return M
