local FreeCameraScene = require("src.scenes.FreeCameraScene")
local World = require("src.world.world")

---@class MainScene: FreeCameraScene
local MainScene = FreeCameraScene()

function MainScene:init()
    local center = math.floor(World.TILE_SIZE / 2)
    local wtz = consts.WORLD_TILE_SIZE
    self.camera:setPos((center + 0.5) * wtz, (center + 0.5) * wtz)
    self.allowMousePan = false -- We'll do pan ourselves
    ---@type [integer,integer]?
    self.candidateWirePos = nil
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

    if self.candidateWirePos then
        love.graphics.line(
            (tx + 0.5) * wtz,
            (ty + 0.5) * wtz,
            (self.candidateWirePos[1] + 0.5) * wtz,
            (self.candidateWirePos[2] + 0.5) * wtz
        )
    end

    self:resetCamera()
    ui.startUI()

    -- TODO: Move this to HUD
    local hud = g.getHUD()
    hud:draw()
    local safeArea = hud:getSafeArea()

    love.graphics.setColor(0, 0, 0, 1)
    if world.heat:contains(tx, ty) then
        love.graphics.print("("..tx..", "..ty..") H: "..world.heat:get(tx, ty), g.getMainFont(16), safeArea.x + 4, safeArea.y + safeArea.h - 18)
    else
        love.graphics.print("("..tx..", "..ty..")", g.getMainFont(16), safeArea.x + 4, safeArea.y + safeArea.h - 18)
    end
    if self.candidateWirePos then
        love.graphics.print("Sel: ("..self.candidateWirePos[1]..", "..self.candidateWirePos[2]..")", g.getMainFont(16), safeArea.x + 4, safeArea.y + safeArea.h - 36)
    end

    local item = g.getItem(tx, ty)
    if item then
        local itemInfo, cat = g.getItemInfo(item.type)
        if cat == "server" then
            ---@cast item g.World.ServerData
            local text = "SV - "..item.computePerSecond.." CPS"
            love.graphics.print(text, g.getMainFont(16), safeArea.x + 4, safeArea.y + safeArea.h - 54)
        elseif cat == "data" then
            ---@cast item g.World.DataProcessorData
            ---@cast itemInfo g.DataInfo
            local text = "DP - "..item.serversDataPerSecond.." TDPS "..itemInfo.dataPerSecond
            love.graphics.print(text, g.getMainFont(16), safeArea.x + 4, safeArea.y + safeArea.h - 54)
        end
    end

    ui.endUI()
end

function MainScene:_getTilePos()
    local mx, my = self.camera:toWorld(love.mouse.getPosition())
    local wtz = consts.WORLD_TILE_SIZE
    local tx, ty = math.floor(mx / wtz), math.floor(my / wtz)
    return tx, ty
end

---@param k love.KeyConstant
function MainScene:keyreleased(k)
    if consts.DEV_MODE and g.hasSession() then
        if k == "1" then
            local tx, ty = self:_getTilePos()

            if g.canPutItem(tx, ty) then
                g.putItem("basic_server", tx, ty)
            end
        elseif k == "2" then
            local tx, ty = self:_getTilePos()

            if g.canPutItem(tx, ty) then
                g.putItem("basic_data", tx, ty)
            end
        elseif k == "3" then
            local tx, ty = self:_getTilePos()

            if self.candidateWirePos then
                local world = g.getMainWorld()
                local server, dp = nil, nil
                -- Get info on 1st tile pos
                local firstItem = g.getItem(self.candidateWirePos[1], self.candidateWirePos[2])
                if firstItem then
                    local _, category = g.getItemInfo(firstItem.type)
                    if category == "server" then
                        ---@cast firstItem g.World.ServerData
                        server = firstItem
                    elseif category == "data" then
                        ---@cast firstItem g.World.DataProcessorData
                        dp = firstItem
                    end
                end
                -- Get info on 2nd tile pos
                local secondItem = g.getItem(tx, ty)
                if secondItem then
                    local _, category = g.getItemInfo(secondItem.type)
                    if category == "server" then
                        ---@cast secondItem g.World.ServerData
                        server = secondItem
                    elseif category == "data" then
                        ---@cast secondItem g.World.DataProcessorData
                        dp = secondItem
                    end
                end
                if server and dp then
                    if server.connectsTo == dp then
                        g.disconnectDataWire(server, dp)
                    elseif g.canConnectDataWire(server, dp) then
                        g.connectDataWire(server, dp)
                    end
                end
                self.candidateWirePos = nil
            else
                self.candidateWirePos = {tx, ty}
            end
        elseif k == "4" then
            local tx, ty = self:_getTilePos()
            g.removeItem(tx, ty)
        elseif k == "return" then
            print(g.queueJob({
                name = "Test Job",
                category = "general",
                computePower = 5,
                outputData = 5,
                resource = {money = 1},
                timeout = 30
            }))
        end
    end
end

return MainScene
