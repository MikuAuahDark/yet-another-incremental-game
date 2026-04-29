local FreeCameraScene = require("src.scenes.FreeCameraScene")
local World = require("src.world.world")
local tutorial = require(".tutorial")

---@class MainScene: FreeCameraScene
local MainScene = FreeCameraScene()

function MainScene:init()
    local center = math.floor(World.TILE_SIZE / 2)
    local wtz = consts.WORLD_TILE_SIZE
    self.camera:setPos((center + 0.5) * wtz, (center + 0.5) * wtz)

    ---@type [integer,integer]?
    self.pinPosition = nil
    ---@type [number,number]?
    self.lastPan = nil

    -- We track our own zoom because our zoom needs to be affected by UI scaling
    self.zoomValue = 0

    self.hideHUD = false
end
MainScene.mousemoved = MainScene.defaultMousemoved

function MainScene:enter()
    self.hideHUD = false
    g.getHUD().selectedItem = nil
end

---@param dt number
function MainScene:update(dt)
    local z = self:zoomFromScale(ui.getUIScaling())
    self:setZoom(z + self.zoomValue)
    self.camera:setViewport(0, 0, love.graphics.getDimensions())
    g.getHUD():update(dt)
end

function MainScene:draw()
    local hud = g.getHUD()
    local safeArea = hud:getSafeArea()
    local s = g.getSn()

    self:setCamera()

    local world = g.getMainWorld()
    world:_draw()

    local mx, my = iml.getTransformedPointer()
    -- Draw tile selection
    local wtz = consts.WORLD_TILE_SIZE
    local tx, ty = math.floor(mx / wtz), math.floor(my / wtz)
    if world.items:contains(tx, ty) then
        world:_setHoveredTile(tx, ty)

        -- tile indicator
        love.graphics.setColor(0, 0, 0, 1)
        local t = math.sin(love.timer.getTime() * 4) ^ 2
        local drawItemPreview = nil
        if hud.selectedItem then
            if hud.selectedItem == "" then
                local item = g.getItem(tx, ty)
                if item and item.removable then
                    love.graphics.setColor(0, 1, 0, t)
                else
                    love.graphics.setColor(1, 0, 0, t)
                end
            else
                if g.getItemInventoryCount(hud.selectedItem) > 0 then
                    if g.canPutItem(tx, ty) then
                        love.graphics.setColor(0, 1, 0, t)
                        drawItemPreview = g.getItemInfo(hud.selectedItem)
                    else
                        love.graphics.setColor(1, 0, 0, t)
                    end
                else
                    hud.selectedItem = nil
                end
            end
        end

        love.graphics.rectangle("line", tx * wtz, ty * wtz, wtz, wtz)

        if drawItemPreview then
            local itemR = Kirigami(tx * wtz, ty * wtz, wtz, wtz)
            local col = gsman.setColor(1, 1, 1, 0.5)
            drawItemPreview.drawItem(itemR:padRatio(0.25))
            col:pop()
        end
    else
        world:_setHoveredTile(nil, nil)
    end

    self:resetCamera()
    ui.startUI()
    local uimx, uimy = ui.getMouse()

    -- Zooming on world
    if safeArea:containsCoords(uimx, uimy) then
        local wx, wy = iml.consumeWheelMove()
        if wx and wy then
            self.zoomValue = self.zoomValue + wy / 5
        end
    end

    if self.hideHUD then
        hud:draw({stats = false, jobQueue = false, itemList = false, mode = "main"})

        local r = ui.getFullScreenRegion()
        local drag = ui.region.consumeDrag("moveworld", r, 1)
        if drag then
            -- Panning
            local x, y = ui.getUIScalingTransform():transformPoint(drag.endX, drag.endY)
            if self.lastPan then
                local cx, cy = self.camera:getPos() --[[@as number]]
                local z = self:scaleFromZoom(self._zoomIndex)
                local dx = x - self.lastPan[1]
                local dy = y - self.lastPan[2]
                self.camera:setPos(cx - dx / z, cy - dy / z)
            end
            self.lastPan = {x, y}
        else
            self.lastPan = nil
            if ui.region.wasJustClicked(r, 1, "moveworld") then
                self.hideHUD = false
            end
        end
    else
        -- Draw tile selection info text
        love.graphics.setColor(1, 1, 1)
        if world.heat:contains(tx, ty) then
            helper.printTextOutlineSimple(
                "("..tx..", "..ty..") H: "..helper.round(world.heat:get(tx, ty), 2),
                g.getMainFont(16), 1,
                safeArea.x + 4,
                safeArea.y + safeArea.h - 18
            )
        else
            helper.printTextOutlineSimple(
                "("..tx..", "..ty..")",
                g.getMainFont(16), 1,
                safeArea.x + 4,
                safeArea.y + safeArea.h - 18
            )
        end

        -- Draw tile selection tooltip
        local selectedItem = nil
        if self.pinPosition then
            local selTx, selTy = self.pinPosition[1], self.pinPosition[2]

            if not world:isWithinWorldLimit(selTx, selTy) then
                self.pinPosition = nil
            else
                selectedItem = g.getItem(selTx, selTx)
            end
        end

        if not selectedItem then
            if world:isWithinWorldLimit(tx, ty) then
                selectedItem = g.getItem(tx, ty)
            end
        end

        hud:draw({mode = "main"})

        if selectedItem then
            -- Draw tooltip
            local uix, uiy
            if self.pinPosition then
                local selTx, selTy = self.pinPosition[1], self.pinPosition[2]
                ---@type number,number
                uix, uiy = ui.getUIScalingTransform():inverseTransformPoint(
                    self.camera:toScreen((selTx + 0.5) * wtz, (selTy + 0.5) * wtz)
                )
            else
                uix, uiy = uimx + 11, uimy + 5
            end

            ui.ItemTooltip.DrawWorldTooltip(selectedItem, uix, uiy, safeArea)
        end

        local drag = ui.region.consumeDrag("moveworld", safeArea, 1)
        if drag then
            -- Panning
            local x, y = ui.getUIScalingTransform():transformPoint(drag.endX, drag.endY)
            if self.lastPan then
                local cx, cy = self.camera:getPos() --[[@as number]]
                local z = self:scaleFromZoom(self._zoomIndex)
                local dx = x - self.lastPan[1]
                local dy = y - self.lastPan[2]
                self.camera:setPos(cx - dx / z, cy - dy / z)
            end
            self.lastPan = {x, y}
        else
            self.lastPan = nil
        end

        if hud.selectedItem then
            if ui.region.wasJustClicked(safeArea, 1, "moveworld") then
                if hud.selectedItem == "" then
                    -- Item deletion
                    local item = g.getItem(tx, ty)
                    if item and item.removable then
                        g.removeItem(tx, ty)
                    end
                else
                    -- Item placement
                    if g.canPutItem(tx, ty) then
                        g.putItem(hud.selectedItem, tx, ty)

                        -- Tutorial
                        if s.showTutorials.start == 0 and hud.selectedItem == "basic_server" then
                            s.showTutorials.start = 1
                        elseif s.showTutorials.start == 1 and hud.selectedItem == "basic_indata" then
                            s.showTutorials.start = 2
                        elseif s.showTutorials.start == 2 and hud.selectedItem == "basic_data" then
                            s.showTutorials.start = 3
                        end
                    end
                end
            elseif ui.region.wasJustClicked(safeArea, 2, "moveworld") then
                hud.selectedItem = nil
            end
        elseif ui.region.wasJustClicked(safeArea, 1, "moveworld") then
            -- Item description pinning
            local item = g.getItem(tx, ty)
            if item then
                self.pinPosition = {tx, ty}
            else
                self.pinPosition = nil
            end
        end
    end

    if not self.hideHUD then
        -- Draw scene switch
        local switchR, switchImageR = ui.getTooltipRegion(hud.topR.x + hud.topR.w - 56, hud.topR.y + hud.topR.h + 8, 40, 40, ui.getScreenRegion())
        love.graphics.setColor(1, 1, 1)
        ui.Tooltip(switchR, objects.Color.BLACK, objects.Color.WHITE)
        g.drawImageContained("account_tree", switchImageR:get())
        if iml.wasJustClicked(switchR:get()) then
            g.playUISound("ui_click_basic", 1.4,0.8)
            g.gotoScene("upgrade_scene")
        end
        -- Tutorial state 5 needs to get to tech tree
        if s.showTutorials.start == 5 then
            local x, y = switchR:getCenter()
            local col = gsman.setColor(1, 0, 0)
            local lw = gsman.setLineWidth(6)
            helper.circleHighlight(x, y, switchR.w / 1.7)
            lw:pop()
            col:pop()

            ui.TooltipBuilder(switchR.x + switchR.w, switchR.y + switchR.h + 24, 1, 0, safeArea, 120)
                :addText(TEXT.TUTORIAL_5_0, g.getMainFont(12), "center")
                :render()
        end

        -- Tutorial check
        if s.showTutorials.start == 0 and tutorial[0](safeArea) then
            s.showTutorials.start = 1
        elseif s.showTutorials.start == 1 and tutorial[1](safeArea) then
            s.showTutorials.start = 2
        elseif s.showTutorials.start == 2 and tutorial[2](safeArea) then
            s.showTutorials.start = 3
        elseif s.showTutorials.start == 3 and tutorial[3](safeArea) then
            s.showTutorials.start = 4
        elseif s.showTutorials.start == 4 and tutorial[4](safeArea) then
            s.showTutorials.start = 5
        end
    end

    -- Draw item visual on cursor
    if hud.selectedItem then
        local t = math.sin(love.timer.getTime() * 5)
        local itemR = Kirigami(uimx + 6, uimy + 6 + t * 3, 48, 48)

        if hud.selectedItem == "" then
            -- Delete
            local col = gsman.setColor(1, 0, 0)
            g.drawImageContained("delete", itemR:padRatio(0.2):get())
            col:pop()
        else
            -- Place
            local itemInfo = g.getItemInfo(hud.selectedItem)
            local col = gsman.setColor(1, 1, 1, 0.5)
            itemInfo.drawItem(itemR)
            col:pop()
        end
    end

    -- Check if visibility button was pressed
    if hud.wasVisibilityButtonPressed then
        self.hideHUD = true
    end
    if hud.wasResetCameraButtonPressed then
        self:_resetCamera()
    end

    self:renderPause()

    ui.endUI()
end


function MainScene:perSecondUpdate()
    local tree = g.getUpgTree()
    tree.priceBurnout = math.max(tree.priceBurnout * consts.UPGADE_BURNOUT_DECAY, 1)
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
            ---@cast firstItem g.World.DataOutputData
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
            ---@cast secondItem g.World.DataOutputData
            dp = secondItem
        end
    end

    return server, dp
end

---@param server g.World.ServerData
---@param dp g.World.DataOutputData
function MainScene:_canConnectOrDisconnect(server, dp)
    if helper.index(server.connectedOutputs, dp) then
        return true
    elseif g.canConnectDataWire(server, dp) then
        return true
    end
    return false
end


function MainScene:_resetCamera()
    local center = math.floor(World.TILE_SIZE / 2)
    local wtz = consts.WORLD_TILE_SIZE
    self.camera:setPos((center + 0.5) * wtz, (center + 0.5) * wtz)
    self.zoomValue = 0
end

function MainScene:keyreleased(k)
    if k == "tab" then
        g.gotoScene("upgrade_scene")
    elseif k == "escape" then
        local s = g.getSn()
        s.paused = not s.paused
    end
end

return MainScene
