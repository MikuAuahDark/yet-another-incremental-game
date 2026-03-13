local ItemTooltip = require("src.ui.tooltip")

---@param upgrade g.Tree.Upgrade
---@param x number
---@param y number
---@param safeArea kirigami.Region
local function description(upgrade, x, y, safeArea)
    local uinfo = g.getUpgradeInfo(upgrade.id)
    local titleF = ItemTooltip.getTitleFont()
    local attrF = ItemTooltip.getAttrFont()
    local descF = ItemTooltip.getDescFont()

    local titleFH = titleF:getHeight()
    local attrFH = attrF:getHeight()
    local descFH = descF:getHeight()

    local MAX_TOOLTIP_WIDTH = 250
    local width, height = 150, 0

    -- 1. Title (at the top)
    local titleText = uinfo.name
    local titleHeight
    do
        local w, l = richtext.getWrap(titleText, titleF, MAX_TOOLTIP_WIDTH)
        width = math.max(width, w)
        titleHeight = l * titleFH
        height = height + titleHeight
    end

    -- 2. Attributes (if UNLOCKS)
    local attributesText, attributesHeight = nil, 0
    if uinfo.kind == "UNLOCKS" and uinfo.targetItem then
        local itemInfo, category = g.getItemInfo(uinfo.targetItem)
        local at = {}
        local world = g.getMainWorld()

        -- Load
        local load = world:computeLoadModifier(itemInfo)
        at[#at+1] = TEXT.LOAD_TOOLTIP({load = g.formatNumber(load)})

        if category == "server" then
            ---@cast itemInfo g.ServerInfo
            at[#at+1] = TEXT.CPS_NUMBER({cps = g.formatNumber(itemInfo.computePerSecond)})
            at[#at+1] = TEXT.HEAT_TOLERANCE({
                min_heat = itemInfo.heatTolerance[1],
                max_heat = itemInfo.heatTolerance[2]
            })
        elseif category == "data" then
            ---@cast itemInfo g.DataInfo
            at[#at+1] = TEXT.DPS_NUMBER({dps = g.formatNumber(itemInfo.dataPerSecond)})
            at[#at+1] = TEXT.WIRE_RANGE({range = itemInfo.wireLength})
            if itemInfo.wireCount then
                at[#at+1] = TEXT.MAX_WIRE_COUNT({s = itemInfo.wireCount})
            end
        end

        if #at > 0 then
            attributesText = table.concat(at, "\n")
            local w, l = richtext.getWrap(attributesText, attrF, MAX_TOOLTIP_WIDTH)
            width = math.max(width, w)
            attributesHeight = l * attrFH
            height = height + attributesHeight
        end
    end

    -- 3. Description (use g.getUpgradeDescription)
    local descriptionText = g.getUpgradeDescription(uinfo, upgrade.level, true)
    local descriptionHeight = 0
    if #descriptionText > 0 then
        local w, l = richtext.getWrap(descriptionText, descF, MAX_TOOLTIP_WIDTH)
        width = math.max(width, w)
        descriptionHeight = l * descFH
        height = height + descriptionHeight
    end

    -- 4. Level Line (above price)
    local maxLevel = g.getUpgTree():getUpgradeMaxLevel(upgrade)
    local levelText = "Level: " .. upgrade.level .. (maxLevel > 0 and ("/" .. maxLevel) or "")
    local levelHeight
    do
        local w, l = richtext.getWrap(levelText, descF, MAX_TOOLTIP_WIDTH)
        width = math.max(width, w)
        levelHeight = l * descFH
        height = height + levelHeight
    end

    -- 5. Price (bottommost)
    local price = g.getUpgTree():getUpgradePrice(upgrade)
    ---@type string[]
    local priceStrs = {}
    for _, resId in ipairs(g.RESOURCE_LIST) do
        local val = price[resId] or 0
        if val > 0 then
            priceStrs[#priceStrs+1] = "{"..resId.."}" .. g.formatNumber(val)
        end
    end
    local priceText = table.concat(priceStrs, " ")
    local priceHeight = 0
    if #priceStrs > 0 then
        local w, l = richtext.getWrap(priceText, titleF, MAX_TOOLTIP_WIDTH)
        width = math.max(width, w)
        priceHeight = l * titleFH
        height = height + priceHeight
    end

    -- Generate region
    local tdrawableR, tcntR = ui.getTooltipRegion(x, y, width, height, safeArea)
    ui.Tooltip(tdrawableR, objects.Color.BLACK, objects.Color.WHITE)

    -- Draw
    local currHeight = 0
    -- Title
    richtext.printRich(titleText, titleF, tcntR.x, tcntR.y + currHeight, tcntR.w, "center")
    currHeight = currHeight + titleHeight

    -- Attributes
    if attributesText then
        richtext.printRich(attributesText, attrF, tcntR.x, tcntR.y + currHeight, tcntR.w, "left")
        currHeight = currHeight + attributesHeight
    end

    -- Description
    if #descriptionText > 0 then
        richtext.printRich(descriptionText, descF, tcntR.x, tcntR.y + currHeight, tcntR.w, "center")
        currHeight = currHeight + descriptionHeight
    end

    -- Level
    richtext.printRich(levelText, descF, tcntR.x, tcntR.y + currHeight, tcntR.w, "center")
    currHeight = currHeight + levelHeight

    -- Price
    if priceHeight > 0 then
        richtext.printRich(priceText, titleF, tcntR.x, tcntR.y + currHeight, tcntR.w, "center")
    end
end

return description
