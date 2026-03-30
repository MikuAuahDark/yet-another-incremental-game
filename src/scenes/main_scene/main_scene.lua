local FreeCameraScene = require("src.scenes.FreeCameraScene")
local World = require("src.world.world")

local DOUBLE_CLICK_TIMEOUT = 0.5

---@class MainScene: FreeCameraScene
local MainScene = FreeCameraScene()

function MainScene:init()
    local center = math.floor(World.TILE_SIZE / 2)
    local wtz = consts.WORLD_TILE_SIZE
    self.camera:setPos((center + 0.5) * wtz, (center + 0.5) * wtz)

    ---@type [integer,integer]?
    self.candidateWirePos = nil
    ---@type g.World.ItemData? pinning item description
    self.pinItemInfo = nil
    ---@type [number,g.World.ItemData]?
    self.targetDrag = nil
    ---@type [number,g.World.DataProcessorData]?
    self.dpDoubleClickData = nil
end
MainScene.mousemoved = MainScene.defaultMousemoved

---@param dt number
function MainScene:update(dt)
    local z = self:zoomFromScale(ui.getUIScaling())
    self:setZoom(z)
    self.camera:setViewport(0, 0, love.graphics.getDimensions())
    g.getHUD():update(dt)

    if self.pinItemInfo and self.pinItemInfo.removed then
        self.pinItemInfo = nil
    end

    if self.targetDrag then
        if self.targetDrag[2].removed then
            self.targetDrag = nil
        else
            self.targetDrag[1] = self.targetDrag[1] + dt
        end
    end

    if self.dpDoubleClickData then
        self.dpDoubleClickData[1] = math.max(self.dpDoubleClickData[1] - dt, 0)
        if self.dpDoubleClickData[1] <= 0 then
            self.dpDoubleClickData = nil
        end
    end
end

function MainScene:draw()
    local hud = g.getHUD()
    local safeArea = hud:getSafeArea()

    self:setCamera()

    local world = g.getMainWorld()
    world:_draw()

    -- Dismiss pinned item info if needed
    if not self.targetDrag then
        if iml.wasJustClicked(self:_regionFromUIToWorld(safeArea):get()) then
            self.pinItemInfo = nil
        end
    end

    local mx, my = iml.getTransformedPointer()
    -- Draw tile selection
    local wtz = consts.WORLD_TILE_SIZE
    local tx, ty = math.floor(mx / wtz), math.floor(my / wtz)
    local item = nil
    local beforeActiveDragWorld, currentActiveDragWorld = self.targetDrag, nil
    if world.items:contains(tx, ty) then
        -- tile indicator
        local t = math.sin(love.timer.getTime() * 4) ^ 2
        if self.candidateWirePos then
            local server, dp = self:_getServerAndDP(self.candidateWirePos[1], self.candidateWirePos[2], tx, ty)
            if server and dp and self:_canConnectOrDisconnect(server, dp) then
                love.graphics.setColor(0, 1, 0, t)
            else
                love.graphics.setColor(1, 0, 0, t)
            end
        elseif hud.activeDragging and hud.activeDragging[1] >= consts.DRAG_ITEM_DURATION then
            if g.canPutItem(tx, ty) then
                love.graphics.setColor(0, 1, 0, t)
            else
                love.graphics.setColor(1, 0, 0, t)
            end
        elseif self.targetDrag and self.targetDrag[1] >= consts.DRAG_ITEM_DURATION then
            if (tx == self.targetDrag[2].tileX and ty == self.targetDrag[2].tileY) or g.canPutItem(tx, ty) then
                love.graphics.setColor(0, 1, 0, t)
            else
                love.graphics.setColor(1, 0, 0, t)
            end
        else
            love.graphics.setColor(0, 0, 0, 1)
        end
        love.graphics.rectangle("line", tx * wtz, ty * wtz, wtz, wtz)

        item = self.targetDrag and self.targetDrag[2]
        if not item then
            item = g.getItem(tx, ty)
        end

        if item then
            local x, y = item.tileX * wtz, item.tileY * wtz
            local drag = iml.consumeDrag(item, x, y, wtz, wtz, 1)
            if drag or iml.isClicked(x, y, wtz, wtz, 1, item) then
                if not drag then
                    self.pinItemInfo = item
                end

                if self.targetDrag and self.targetDrag[2] ~= item or not self.targetDrag then
                    self.targetDrag = {0, item}
                end
            else
                self.targetDrag = nil

                if iml.wasJustClicked(x, y, wtz, wtz, 1, item) then
                    -- Double-clicking data processor?
                    local itemInfo = g.getItemInfo(item.type)
                    if itemInfo.category == "data" then
                        ---@cast item g.World.DataProcessorData
                        if self.dpDoubleClickData and self.dpDoubleClickData[1] > 0 and self.dpDoubleClickData[2] == item then
                            -- Initiate wire connection
                            self.candidateWirePos = {item.tileX, item.tileY}
                            self.dpDoubleClickData = nil
                        else
                            -- Begin double click check
                            self.dpDoubleClickData = {DOUBLE_CLICK_TIMEOUT, item}
                        end
                    end
                end
            end
        end
    end
    currentActiveDragWorld = self.targetDrag

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
    local uimx, uimy = ui.getMouse()

    love.graphics.setColor(0, 0, 0, 1)
    if world.heat:contains(tx, ty) then
        love.graphics.print("("..tx..", "..ty..") H: "..world.heat:get(tx, ty), g.getMainFont(16), safeArea.x + 4, safeArea.y + safeArea.h - 18)
    else
        love.graphics.print("("..tx..", "..ty..")", g.getMainFont(16), safeArea.x + 4, safeArea.y + safeArea.h - 18)
    end
    if self.candidateWirePos then
        love.graphics.print(
            "Sel: ("..self.candidateWirePos[1]..", "..self.candidateWirePos[2]..")",
            g.getMainFont(16),
            safeArea.x + 4, safeArea.y + safeArea.h - 36
        )
    end

    if (not currentActiveDragWorld or currentActiveDragWorld[1] < consts.DRAG_ITEM_DURATION) and (not hud.activeDragging) then
        if self.pinItemInfo then
            -- Draw pinned tooltip
            ---@type number,number
            local uix, uiy = ui.getUIScalingTransform():inverseTransformPoint(
                self.camera:toScreen((self.pinItemInfo.tileX + 0.5) * wtz, (self.pinItemInfo.tileY + 0.5) * wtz)
            )
            ui.ItemTooltip.DrawWorldTooltip(self.pinItemInfo, uix, uiy, safeArea)
        end
        if item and self.pinItemInfo ~= item then
            -- Draw hovered tooltip
            ui.ItemTooltip.DrawWorldTooltip(item, uimx + 11, uimy + 5, safeArea)
        end
    end

    -- Update item dragging (from world)
    if currentActiveDragWorld then
        if currentActiveDragWorld[1] < consts.DRAG_ITEM_DURATION then
            local t = helper.clamp(helper.remap(currentActiveDragWorld[1], 0, consts.DRAG_ITEM_DURATION, 0, 1), 0, 1)
            ui.arcLoadingBar(uimx, uimy, t)
        else
        end
    elseif beforeActiveDragWorld and beforeActiveDragWorld[1] >= consts.DRAG_ITEM_DURATION then
        -- Move or remove?
        if helper.isInsideRect(uimx, uimy, safeArea:get()) then
            -- Move if possible
            if g.canPutItem(tx, ty) then
                g.moveItem(beforeActiveDragWorld[2], tx, ty)
            end
        else
            -- Remove
            g.removeItem(beforeActiveDragWorld[2])
        end
    end

    -- Update item dragging (from HUD)
    -- FIXME: Callback-based?
    local beforeActiveDragHUD = hud.activeDragging
    hud:draw()
    local currentActiveDragHUD = hud.activeDragging

    if currentActiveDragHUD then
        if currentActiveDragHUD[1] < consts.DRAG_ITEM_DURATION then
            local t = helper.clamp(helper.remap(currentActiveDragHUD[1], 0, consts.DRAG_ITEM_DURATION, 0, 1), 0, 1)
            ui.arcLoadingBar(uimx, uimy, t)
        elseif currentActiveDragHUD[3] > 0 then
            local t = helper.EASINGS.sineOut(math.min(currentActiveDragHUD[3], 1))
            hud:drawCancelIntuition("cancel", t)
        end
    elseif beforeActiveDragHUD and beforeActiveDragHUD[1] >= consts.DRAG_ITEM_DURATION then
        -- Place or put out?
        if helper.isInsideRect(uimx, uimy, safeArea:get()) then
            -- Place
            -- TODO: Check money
            if g.canPutItem(tx, ty) then
                g.putItem(beforeActiveDragHUD[2].id, tx, ty)
            end
        end
    end

    if currentActiveDragWorld then
        local t0 = math.min((currentActiveDragWorld[1] - consts.DRAG_ITEM_DURATION) * 2, 1)
        if t0 > 0 then
            local t = helper.EASINGS.sineOut(t0)
            hud:drawCancelIntuition("delete", t)
        end
    end

    -- Draw scene switch
    local switchR, switchImageR = ui.getTooltipRegion(hud.topR.x + hud.topR.w - 56, hud.topR.y + hud.topR.h + 8, 40, 40, ui.getScreenRegion())
    love.graphics.setColor(1, 1, 1)
    ui.Tooltip(switchR, objects.Color.BLACK, objects.Color.WHITE)
    g.drawImageContained("account_tree", switchImageR:get())
    if iml.wasJustClicked(switchR:get()) then
        g.playUISound("ui_click_basic", 1.4,0.8)
        g.gotoScene("upgrade_scene")
    end

    -- Draw item visual
    local showVisualForItem = nil

    if currentActiveDragWorld and currentActiveDragWorld[1] >= consts.DRAG_ITEM_DURATION then
        showVisualForItem = g.getItemInfo(currentActiveDragWorld[2].type)
    elseif currentActiveDragHUD and currentActiveDragHUD[1] >= consts.DRAG_ITEM_DURATION then
        showVisualForItem = currentActiveDragHUD[2]
    end

    if showVisualForItem then
        -- TODO: Visual feedback when placing
        local col = gsman.setColor(1, 1, 1, 0.5)
        local t = math.sin(love.timer.getTime() * 5)
        local itemR = Kirigami(uimx + 6, uimy + 6 + t * 3, 48, 48)
        showVisualForItem.drawItem(itemR)
        col:pop()

        self.pinItemInfo = nil
    end

    ui.endUI()
end


---@param server g.World.ServerData
---@param job g.Job
function MainScene:jobCompleted(server, job)
    local x = (server.tileX + 0.5) * consts.WORLD_TILE_SIZE
    local y = (server.tileY + 0.5) * consts.WORLD_TILE_SIZE
    local money = assert(job.resource and job.resource.money)
    worldutil.spawnText("{o}"..job.name.." +{money}"..g.formatNumber(money).."{/o}", x, y, 0.5, 15)
end



function MainScene:_getTilePos()
    local mx, my = self.camera:toWorld(love.mouse.getPosition())
    local wtz = consts.WORLD_TILE_SIZE
    local tx, ty = math.floor(mx / wtz), math.floor(my / wtz)
    return tx, ty
end

---@param r kirigami.Region
function MainScene:_regionFromUIToWorld(r)
    local uit = ui.getUIScalingTransform()
    local x1, y1 = self.camera:toWorld(uit:transformPoint(r.x, r.y))
    local x2, y2 = self.camera:toWorld(uit:transformPoint(r.x + r.w, r.y + r.h))
    return Kirigami(x1, y1, x2 - x1, y2 - y1)
end

function MainScene:_getServerAndDP(tx1, ty1, tx2, ty2)
    local world = g.getMainWorld()
    local server, dp = nil, nil
    -- Get info on 1st tile pos
    local firstItem = g.getItem(tx1, ty1)
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
    local secondItem = g.getItem(tx2, ty2)
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

    return server, dp
end

---@param server g.World.ServerData
---@param dp g.World.DataProcessorData
function MainScene:_canConnectOrDisconnect(server, dp)
    if server.connectsTo == dp then
        return true
    elseif g.canConnectDataWire(server, dp) then
        return true
    end
    return false
end



MainScene.keyreleased = MainScene.defaultKeyreleased

---@param x number
---@param y number
---@param b integer
function MainScene:mousereleased(x, y, b)
    if self.candidateWirePos and b == 1 then
        self.candidateWirePos = nil
    end
end

function MainScene:keyreleased(k)
    if k == "tab" then
        g.gotoScene("upgrade_scene")
    end
end

return MainScene
