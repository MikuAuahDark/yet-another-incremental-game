
local FreeCameraScene = require("src.scenes.FreeCameraScene")
local vignette = require("src.modules.vignette.vignette")

---@class AsteroidScene: FreeCameraScene
local AsteroidScene = FreeCameraScene()

function AsteroidScene:init()
    self.allowMousePan = false
    g.newSession()
end

---@param dt number
function AsteroidScene:update(dt)
end

function AsteroidScene:draw()
    ui.startUI()

    -- Draw grid
    do
        local lineWidthSetter = gsman.setLineWidth(4)
        local CELL_SIZE = 40
        local w, h = ui.getScaledUIDimensions()
        local ox = math.floor(w / CELL_SIZE) * CELL_SIZE - w
        local oy = math.floor(h / CELL_SIZE) * CELL_SIZE - h

        love.graphics.setColor(objects.Color("3026F0AD"))

        -- Vertical
        for x = ox, w, CELL_SIZE do
            love.graphics.line(x, -4, x, h + 4)
        end

        -- Horizontal
        for y = oy, h, CELL_SIZE do
            love.graphics.line(-4, y, w + 4, y)
        end
        lineWidthSetter:pop()
    end

    g.getMainWorld():_draw()

    ui.endUI()
end

---@param tpool g.TokenPool
function AsteroidScene:populateTokenPool(tpool)
    tpool:add("triangle_small", 10)
end

return AsteroidScene
