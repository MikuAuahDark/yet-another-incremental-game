
local FreeCameraScene = require("src.scenes.FreeCameraScene")
local vignette = require("src.modules.vignette.vignette")

---@class AsteroidScene: FreeCameraScene
local AsteroidScene = FreeCameraScene()

function AsteroidScene:init()
    self.allowMousePan = false
end

---@param dt number
function AsteroidScene:update(dt)
end

function AsteroidScene:draw()
end

return AsteroidScene
