---@class ui.ItemTooltip
local ItemTooltip = {}

local MAX_TOOLTIP_WIDTH = 200

----------------
-- Rule of thumb: Divide/multiply by 1.6 for font sizes
----------------

---@param serverData g.World.ServerData
---@param mx number
---@param my number
---@param safeArea kirigami.Region
function ItemTooltip.ServerTooltipWorld(serverData, mx, my, safeArea)
    local serverInfo = g.getItemInfo(serverData.type, "server")
    local titleF = g.getMainFont(16)
    local descF = g.getMainFont(10)
    local width, height = 0, 0

    -- Pass 1: Compute tooltip sizes

    -- Title
    local titleHeight
    do
        local w, l = richtext.getWrap(serverInfo.name, titleF, MAX_TOOLTIP_WIDTH)
        width = helper.clamp(width, w, MAX_TOOLTIP_WIDTH)
        titleHeight = l * titleF:getHeight()
        height = height + titleHeight
    end

    -- Category
    local categoryText, categoryHeight
    do
        local computeNames = {}
        for _, jcname in ipairs(serverInfo.computePreference) do
            computeNames[#computeNames+1] = g.getJobCategoryName(jcname)
        end
        categoryText = TEXT.CATEGORY_LIST({
            categories = table.concat(computeNames, TEXT.HORIZONTAL_LIST_SEPARATOR)
        })
        local w, l = richtext.getWrap(categoryText, descF, MAX_TOOLTIP_WIDTH)
        width = helper.clamp(width, w, MAX_TOOLTIP_WIDTH)
        categoryHeight = l * titleF:getHeight()
        height = height + categoryHeight
    end

    -- TODO: More stuff
    local tdrawableR, tcntR = ui.getTooltipRegion(mx, my, width, height, safeArea)
    ui.Tooltip(tdrawableR, objects.Color.BLACK, objects.Color.WHITE)

    -- Draw the tooltip
    height = 0
    do
        richtext.printRich(serverInfo.name, titleF, tcntR.x, tcntR.y + height, tcntR.w, "center")
        height = height + titleHeight
    end
    -- Draw category
    do
        richtext.printRich(categoryText, descF, tcntR.x, tcntR.y + height, tcntR.w, "center")
        height = height + categoryHeight
    end
end

---@param serverInfo g.ServerInfo
---@param x number relative to bottom center
---@param y number relative to bottom center
function ItemTooltip.ServerTooltipHUD(serverInfo, x, y)
    local titleF = g.getMainFont(16)
    local descF = g.getMainFont(10)
    local width, height = 0, 0

    -- Pass 1: Compute tooltip sizes

    -- Title
    local titleHeight
    do
        local w, l = richtext.getWrap(serverInfo.name, titleF, MAX_TOOLTIP_WIDTH)
        width = helper.clamp(width, w, MAX_TOOLTIP_WIDTH)
        titleHeight = l * titleF:getHeight()
        height = height + titleHeight
    end

    -- Category
    local categoryText, categoryHeight
    do
        local computeNames = {}
        for _, jcname in ipairs(serverInfo.computePreference) do
            computeNames[#computeNames+1] = g.getJobCategoryName(jcname)
        end
        categoryText = TEXT.CATEGORY_LIST({
            categories = table.concat(computeNames, TEXT.HORIZONTAL_LIST_SEPARATOR)
        })
        local w, l = richtext.getWrap(categoryText, descF, MAX_TOOLTIP_WIDTH)
        width = helper.clamp(width, w, MAX_TOOLTIP_WIDTH)
        categoryHeight = l * titleF:getHeight()
        height = height + categoryHeight
    end

    -- TODO: More stuff
    local tdrawableR, tcntR = ui.getTooltipRegion(x - width / 2, y - height, width, height)
    ui.Tooltip(tdrawableR, objects.Color.BLACK, objects.Color.WHITE)

    -- Draw the tooltip
    height = 0
    do
        richtext.printRich(serverInfo.name, titleF, tcntR.x, tcntR.y + height, tcntR.w, "center")
        height = height + titleHeight
    end
    -- Draw category
    do
        richtext.printRich(categoryText, descF, tcntR.x, tcntR.y + height, tcntR.w, "center")
        height = height + categoryHeight
    end
end



---TODO: Specialize this for boosters and data processor.
---Gotta move fast, so this will do for now.
---@param itemData g.World.ItemData
---@param mx number
---@param my number
---@param safeArea kirigami.Region
function ItemTooltip.GenericTooltipWorld(itemData, mx, my, safeArea)
    local itemInfo = g.getItemInfo(itemData.type)
    local titleF = g.getMainFont(16)
    local width, height = 0, 0

    -- Pass 1: Compute tooltip sizes

    -- Title
    local titleHeight
    do
        local w, l = richtext.getWrap(itemInfo.name, titleF, MAX_TOOLTIP_WIDTH)
        width = helper.clamp(width, w, MAX_TOOLTIP_WIDTH)
        titleHeight = l * titleF:getHeight()
        height = height + titleHeight
    end

    local tdrawableR, tcntR = ui.getTooltipRegion(mx, my, width, height, safeArea)
    ui.Tooltip(tdrawableR, objects.Color.BLACK, objects.Color.WHITE)

    -- Pass 2:Draw the tooltip
    height = 0
    do
        richtext.printRich(itemInfo.name, titleF, tcntR.x, tcntR.y + height, tcntR.w, "center")
        height = height + titleHeight
    end
end


---TODO: Specialize this for boosters and data processor.
---Gotta move fast, so this will do for now.
---@param itemInfo g.ItemInfo
---@param x number
---@param y number
function ItemTooltip.GenericTooltipHUD(itemInfo, x, y)
    local titleF = g.getMainFont(16)
    local width, height = 0, 0

    -- Pass 1: Compute tooltip sizes

    -- Title
    local titleHeight
    do
        local w, l = richtext.getWrap(itemInfo.name, titleF, MAX_TOOLTIP_WIDTH)
        width = helper.clamp(width, w, MAX_TOOLTIP_WIDTH)
        titleHeight = l * titleF:getHeight()
        height = height + titleHeight
    end

    local tdrawableR, tcntR = ui.getTooltipRegion(x - width / 2, y - height, width, height)
    ui.Tooltip(tdrawableR, objects.Color.BLACK, objects.Color.WHITE)

    -- Pass 2:Draw the tooltip
    height = 0
    do
        richtext.printRich(itemInfo.name, titleF, tcntR.x, tcntR.y + height, tcntR.w, "center")
        height = height + titleHeight
    end
end

return ItemTooltip
