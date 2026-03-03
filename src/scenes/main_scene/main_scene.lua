local FreeCameraScene = require("src.scenes.FreeCameraScene")

---@class MainScene: FreeCameraScene
local MainScene = FreeCameraScene()

function MainScene:init()
end

---@param dt number
function MainScene:update(dt)
    g.getHUD():update(dt)
end

function MainScene:draw()
    love.graphics.clear(objects.Color("#b0b0b0"))

    ui.startUI()

    -- TODO: Move this to HUD
    g.getHUD():draw()

    ui.endUI()
end

return MainScene
