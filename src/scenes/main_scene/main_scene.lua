local FreeCameraScene = require("src.scenes.FreeCameraScene")
local World = require("src.world.world")

---@class MainScene: FreeCameraScene
local MainScene = FreeCameraScene()

function MainScene:init()
    local center = math.floor(World.TILE_SIZE / 2)
    local wtz = consts.WORLD_TILE_SIZE
    self.camera:setPos((center + 0.5) * wtz, (center + 0.5) * wtz)
    self.allowMousePan = false -- We'll do pan ourselves
end

---@param dt number
function MainScene:update(dt)
    g.getHUD():update(dt)
end

function MainScene:draw()
    love.graphics.clear(objects.Color("#b0b0b0"))

    self:setCamera()

    local world = g.getMainWorld()
    world:_draw()

    local mx, my = iml.getTransformedPointer()
    -- Draw tile selection
    local wtz = consts.WORLD_TILE_SIZE
    local tx, ty = math.floor(mx / wtz), math.floor(my / wtz)
    if world.items:contains(tx, ty) then
        love.graphics.setColor(0, 0, 0, 1)
        love.graphics.rectangle("line", tx * wtz, ty * wtz, wtz, wtz)
    end

    self:resetCamera()
    ui.startUI()

    -- TODO: Move this to HUD
    local hud = g.getHUD()
    hud:draw()
    local safeArea = hud:getSafeArea()

    love.graphics.setColor(0, 0, 0, 1)
    love.graphics.print("("..tx..", "..ty..")", g.getMainFont(16), safeArea.x + 4, safeArea.y + safeArea.h - 18)

    ui.endUI()
end

function MainScene:keyreleased(k)
    if consts.DEV_MODE and g.hasSession() then
        if k == "1" then
            local mx, my = self.camera:toWorld(love.mouse.getPosition())
            local wtz = consts.WORLD_TILE_SIZE
            local tx, ty = math.floor(mx / wtz), math.floor(my / wtz)

            if g.canPutItem(tx, ty) then
                g.putItem("basic_server", tx, ty)
            end
        elseif k == "2" then
            local mx, my = self.camera:toWorld(love.mouse.getPosition())
            local wtz = consts.WORLD_TILE_SIZE
            local tx, ty = math.floor(mx / wtz), math.floor(my / wtz)

            if g.canPutItem(tx, ty) then
                g.putItem("basic_data", tx, ty)
            end
        end
    end
end

return MainScene
