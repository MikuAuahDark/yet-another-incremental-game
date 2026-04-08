
local MAX_TOOLTIP_WIDTH = 200

---@param upgrade g.Tree.Upgrade
---@param tree g.Tree
---@param x number
---@param y number
---@param safeArea kirigami.Region
local function description(upgrade, tree, x, y, safeArea)
    local uinfo = g.getUpgradeInfo(upgrade.id)
    local titleF = ui.ItemTooltip.getTitleFont()
    local attrF = ui.ItemTooltip.getAttrFont()
    local descF = ui.ItemTooltip.getDescFont()

    local titleFH = titleF:getHeight()
    local attrFH = attrF:getHeight()
    local descFH = descF:getHeight()

    local width, height = 150, 0

    -- Title
    local titleText = uinfo.name
    local titleHeight
    do
        local w, l = richtext.getWrap(titleText, titleF, MAX_TOOLTIP_WIDTH)
        width = math.max(width, w)
        titleHeight = l * titleFH
        height = height + titleHeight
    end
    height = height + descFH -- padding

    -- Description
    local level = upgrade.level
    local maxLevel = tree:getUpgradeMaxLevel(upgrade)
    local descriptionText = g.getUpgradeDescription(uinfo, math.max(level, 1), level > 0 and level < maxLevel)
    local descriptionHeight = 0
    if #descriptionText > 0 then
        local w, l = richtext.getWrap(descriptionText, descF, MAX_TOOLTIP_WIDTH)
        width = math.max(width, w)
        descriptionHeight = (l + 1) * descFH
        height = height + descriptionHeight
    end

    -- Attributes (for UNLOCKS upgrade)
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
            ---@cast itemInfo g.DataOutInfo
            at[#at+1] = TEXT.DPS_NUMBER({dps = g.formatNumber(itemInfo.dataPerSecond)})
            at[#at+1] = TEXT.WIRE_RANGE({range = itemInfo.wireLength})
        end

        if #at > 0 then
            attributesText = table.concat(at, "\n")
            local w, l = richtext.getWrap(attributesText, attrF, MAX_TOOLTIP_WIDTH)
            width = math.max(width, w)
            attributesHeight = l * attrFH
            height = height + attributesHeight
            height = height + descFH -- padding
        end
    end

    -- Level Line
    local maxLevel = g.getUpgTree():getUpgradeMaxLevel(upgrade)
    local levelText = "Level: "..upgrade.level..(maxLevel > 0 and ("/"..maxLevel) or "")
    local levelHeight
    do
        local w, l = richtext.getWrap(levelText, descF, MAX_TOOLTIP_WIDTH)
        width = math.max(width, w)
        levelHeight = l * descFH
        height = height + levelHeight
    end

    -- Price (bottommost)
    local price = g.getUpgTree():getUpgradePrice(upgrade)
    ---@type string[]
    local priceStrs = {}

    for _, resId in ipairs(g.RESOURCE_LIST) do
        local val = price[resId] or 0
        if val > 0 then
            local canAfford = g.getResource(resId) >= val
            priceStrs[#priceStrs+1] = helper.wrapRichtextColor(
                canAfford and g.COLORS.CAN_AFFORD or g.COLORS.CANT_AFFORD,
                "{b}{"..resId.."}"..g.formatNumber(val).."{/b}"
            )
        end
    end

    if uinfo.getCustomRequirementText then
        local reqStr = uinfo.getCustomRequirementText(uinfo, upgrade.level)
        if reqStr and reqStr ~= "" then
            local isMet = true
            if uinfo.customRequirementMet then
                isMet = uinfo.customRequirementMet(uinfo, upgrade.level)
            end
            priceStrs[#priceStrs+1] = helper.wrapRichtextColor(
                isMet and g.COLORS.CAN_AFFORD or g.COLORS.CANT_AFFORD,
                reqStr
            )
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
    currHeight = currHeight + titleHeight + descFH -- (descFH is padding)

    -- Attributes
    if attributesText then
        richtext.printRich(attributesText, attrF, tcntR.x, tcntR.y + currHeight, tcntR.w, "left")
        currHeight = currHeight + attributesHeight + descFH -- (descFH is padding)
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
