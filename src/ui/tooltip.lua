---@class ui.ItemTooltip
local ItemTooltip = {}

local MAX_TOOLTIP_WIDTH = 200

---@param serverData g.World.ServerData
---@param mx number
---@param my number
---@param safeArea kirigami.Region
function ItemTooltip.ServerTooltipWorld(serverData, mx, my, safeArea)
    local world = g.getMainWorld()
    local serverInfo = g.getItemInfo(serverData.type, "server")
    local titleF = g.getMainFont(16)
    local attrF = g.getMainFont(12)
    local descF = g.getMainFont(8)
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

    -- Description
    local descriptionHeight = 0
    if serverInfo.description then
        local w, l = richtext.getWrap(serverInfo.description, descF, MAX_TOOLTIP_WIDTH)
        width = helper.clamp(width, w, MAX_TOOLTIP_WIDTH)
        -- Description is padded with 2 empty lines
        descriptionHeight = (l + 2) * descF:getHeight()
        height = height + descriptionHeight
    end

    -- Attributes
    local attributesHeight = 0
    local attributesText
    local heat = g.getTileHeat(serverData.tileX, serverData.tileY)
    do
        local at = {}
        local actualCPS = serverData.computePerSecond
        local baseCPS = serverInfo.computePerSecond
        -- CPS
        local cpsText = TEXT.CPS_NUMBER({cps = g.formatNumber(actualCPS)})
        if actualCPS > baseCPS then
            local p = (actualCPS - baseCPS) / baseCPS
            cpsText = cpsText.." "..helper.wrapRichtextColor(g.COLORS.UI.BUFF, "(+"..helper.round(p * 100, 2).."%)")
        elseif actualCPS < baseCPS then
            local p = (baseCPS - actualCPS) / baseCPS
            cpsText = cpsText.." "..helper.wrapRichtextColor(g.COLORS.UI.DEBUFF, "(-"..helper.round(p * 100, 2).."%)")
        end
        at[#at+1] = cpsText
        -- Heat
        local heatText = TEXT.SERVER_HEAT_NUMBER({
            heat = heat,
            max_heat = serverInfo.heatTolerance[2]
        })
        if heat > serverInfo.heatTolerance[2] then
            heatText = helper.wrapRichtextColor(g.COLORS.UI.DEBUFF, heatText.." {emergency_heat}")
        elseif heat < serverInfo.heatTolerance[1] then
            heatText = helper.wrapRichtextColor(g.COLORS.UI.OVERCLOCKED, heatText.." {snowflake}")
        end
        at[#at+1] = heatText
        attributesText = table.concat(at, "\n")
        local w, l = richtext.getWrap(attributesText, attrF, MAX_TOOLTIP_WIDTH)
        width = helper.clamp(width, w, MAX_TOOLTIP_WIDTH)
        attributesHeight = l * attrF:getHeight()
        height = height + attributesHeight
    end

    -- Log message
    local logText, logHeight = nil, 0
    do
        local l = {}
        if serverData.connectsTo then
            -- Overheat
            if heat > serverInfo.heatTolerance[2] then
                l[#l+1] = helper.wrapRichtextColor(g.COLORS.UI.WARNING, "{emergency_heat} "..TEXT.OVERHEAT_DESCRIPTION)
            end

            -- Data Bottleneck
            if serverData.currentJob and serverData.finalCPS < serverData.computePerSecond then
                l[#l+1] = helper.wrapRichtextColor(g.COLORS.UI.WARNING, "{database} "..TEXT.DATA_BOTTLENECK_DESCRIPTION)
            end

            -- Datacenter Overload
            if world.loadPercentage < 1 then
                l[#l+1] = helper.wrapRichtextColor(g.COLORS.UI.WARNING, "{bolt} "..TEXT.OVERLOADED_DESCRIPTION)
            end
        else
            -- Not connected
            l[#l+1] = helper.wrapRichtextColor(g.COLORS.UI.DEBUFF, "{power_off} "..TEXT.NOT_CONNECTED_DESCRIPTION)
        end

        if #l > 0 then
            logText = table.concat(l, "\n")
            local w, lines = richtext.getWrap(logText, attrF, MAX_TOOLTIP_WIDTH)        width = helper.clamp(width, w, MAX_TOOLTIP_WIDTH)
            logHeight = lines * attrF:getHeight()
            height = height + logHeight
        end
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
    -- Draw description
    if descriptionHeight > 0 then
        local r = Kirigami(tcntR.x, tcntR.y + height, tcntR.w, descriptionHeight)
        ui.printRichInRegion(serverInfo.description, descF, r, true, "left")
        height = height + descriptionHeight
    end
    -- Draw attributes
    do
        richtext.printRich(attributesText, attrF, tcntR.x, tcntR.y + height, tcntR.w, "left")
        height = height + attributesHeight
    end
    -- Draw log message
    if logText then
        local r = Kirigami(tcntR.x, tcntR.y + height, tcntR.w, logHeight)
        ui.printRichInRegion(logText, attrF, r, true, "center")
        height = height + logHeight
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
