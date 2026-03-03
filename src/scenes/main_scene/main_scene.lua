local FreeCameraScene = require("src.scenes.FreeCameraScene")

---@class MainScene: FreeCameraScene
local MainScene = FreeCameraScene()

function MainScene:init()
end

---@param dt number
function MainScene:update(dt)
end

function MainScene:draw()
    love.graphics.clear(objects.Color("#b0b0b0"))

    ui.startUI()
    local lineWidth = gsman.setLineWidth(2)

    -- TODO: Move this to HUD
    local r = ui.getScreenRegion()
    local theme = g.COLORS.UI.MAIN[g.getSystemTheme()]

    local topR = r:set(nil, nil, nil, 24)
    love.graphics.setColor(theme.PANEL)
    love.graphics.rectangle("fill", topR:get())
    love.graphics.setColor(g.COLORS.UI.BORDER)
    love.graphics.rectangle("line", topR:get())

    local leftR = r:set(nil, nil, 150):padUnit(0, topR.h, 0, 0)
    love.graphics.setColor(theme.PANEL)
    love.graphics.rectangle("fill", leftR:get())
    love.graphics.setColor(g.COLORS.UI.BORDER)
    love.graphics.rectangle("line", leftR:get())

    local botR = r:padUnit(leftR.w, 0, 0, 0)
        :set(nil, nil, nil, 72)
        :attachToBottomOf(r)
        :moveRatio(0, -1)
    love.graphics.setColor(theme.PANEL)
    love.graphics.rectangle("fill", botR:get())
    love.graphics.setColor(g.COLORS.UI.BORDER)
    love.graphics.rectangle("line", botR:get())

    local font = g.getMainFont(12)
    richtext.printRichContained("Stats here", font, topR:get())
    richtext.printRichContained("Job queue here", font, leftR:get())
    richtext.printRichContained("Buildings here", font, botR:get())

    lineWidth:pop()
    ui.endUI()
end

return MainScene
