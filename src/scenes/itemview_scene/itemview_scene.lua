local FreeCameraScene = require("src.scenes.FreeCameraScene")

---@class ItemViewScene: FreeCameraScene
local ItemViewScene = FreeCameraScene()

function ItemViewScene:init()
    self.allowMousePan = false
    self.itemIndices = 1
    self.dark = false

    for i, a in ipairs(arg) do
        if a == "--itemview" and arg[i+1] then
            self.itemIndices = tonumber(arg[i+1]) or 1
        end
    end

    self.itemIndices = (self.itemIndices - 1) % #g.ITEMS + 1
end

function ItemViewScene:update(dt)
end

function ItemViewScene:draw()
    ui.startUI()

    if self.dark then
        love.graphics.clear(0.1, 0.1, 0.1)
    else
        love.graphics.clear(0.9, 0.9, 0.9)
    end

    local r = ui.getFullScreenRegion()
    local itemR = r:padRatio(0.5)
        :shrinkToAspectRatio(1, 1)
        :center(r)


    if self.dark then
        love.graphics.setColor(objects.Color.WHITE)
    else
        love.graphics.setColor(objects.Color.BLACK)
    end
    local itemInfo = g.getItemInfo(g.ITEMS[self.itemIndices])
    local f = g.getThickFont(18)
    love.graphics.print(itemInfo.name.."\nID: "..itemInfo.id.."\nIdx: "..self.itemIndices, f, 4, 4)

    love.graphics.setColor(1, 1, 1)
    itemInfo.drawItem(itemR)

    ui.endUI()
end

---@param k love.KeyConstant
function ItemViewScene:keyreleased(k)
    if k == "escape" then
        love.event.quit()
    elseif k == "left" then
        self.itemIndices = (self.itemIndices - 2) % #g.ITEMS + 1
    elseif k == "right" then
        self.itemIndices = self.itemIndices % #g.ITEMS + 1
    elseif k == "space" then
        self.dark = not self.dark
    end
end

return ItemViewScene
