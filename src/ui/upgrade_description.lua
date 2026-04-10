---@param upgrade g.Tree.Upgrade
---@param tree g.Tree
---@param x number
---@param y number
---@param safeArea kirigami.Region
local function description(upgrade, tree, x, y, safeArea)
    local uinfo = g.getUpgradeInfo(upgrade.id)
    local titleF = ui.ItemTooltip.getTitleFont()
    local descF = ui.ItemTooltip.getDescFont()
    local priceF = g.getThickFont(16)
    local builder = ui.TooltipBuilder("hud", x, y, safeArea)

    -- Title
    builder:addText(uinfo.name, titleF, "center")

    -- Description
    local level = upgrade.level
    local maxLevel = tree:getUpgradeMaxLevel(upgrade)
    local descriptionText = g.getUpgradeDescription(uinfo, math.max(level, 1), level > 0 and level < maxLevel)
    if #descriptionText > 0 then
        builder:addText(descriptionText, descF, "center")
    end

    -- Attributes (if kind == "UNLOCKS")
    if uinfo.kind == "UNLOCKS" and uinfo.targetItem then
        local attrF = ui.ItemTooltip.getAttrFont()
        local itemInfo, category = g.getItemInfo(uinfo.targetItem)
        local world = g.getMainWorld()

        -- Load
        local load = world:computeLoadModifier(itemInfo)
        if load > 0 then
            builder:addText(TEXT.LOAD_TOOLTIP({load = g.formatNumber(load)}), attrF, "left")
        end

        if category == "server" then
            ---@cast itemInfo g.ServerInfo
            -- CPS
            builder:addText(TEXT.CPS_NUMBER({cps = g.formatNumber(itemInfo.computePerSecond)}), attrF, "left")
            -- Heat Tolerance
            builder:addText(TEXT.HEAT_TOLERANCE({
                min_heat = itemInfo.heatTolerance[1],
                max_heat = itemInfo.heatTolerance[2]
            }), attrF, "left")
        elseif category == "data" then
            ---@cast itemInfo g.DataOutInfo
            -- DPS
            builder:addText(TEXT.DPS_NUMBER({dps = g.formatNumber(itemInfo.dataPerSecond)}), attrF, "left")
            -- Wire Range
            builder:addText(TEXT.WIRE_RANGE({range = itemInfo.wireLength}), attrF, "left")
            -- Wire DPS
            builder:addText(TEXT.WIRE_DPS({dps = g.formatNumber(itemInfo.wireDPS)}), attrF, "left")
        elseif category == "indata" then
            ---@cast itemInfo g.DataInInfo
            -- Queued Job Category
            builder:addText(TEXT.CATEGORY_LIST({
                categories = g.getJobCategoryName(itemInfo.queuesJob)
            }), attrF, "left")
            -- Added Job Queue
            builder:addText(TEXT.JOB_QUEUE({job = itemInfo.maxJobQueue}), attrF, "left")
            -- Wire Range
            builder:addText(TEXT.WIRE_RANGE({range = itemInfo.wireLength}), attrF, "left")
        elseif category == "powergen" then
            ---@cast itemInfo g.PowerGenInfo
            -- Power
            builder:addText(TEXT.PROVIDE_LOAD_TOOLTIP({power = g.formatNumber(itemInfo.power)}), attrF, "left")
            -- Wire Range
            builder:addText(TEXT.WIRE_RANGE({range = itemInfo.wireLength}), attrF, "left")
        elseif category == "powerrelay" then
            ---@cast itemInfo g.PowerRelayInfo
            -- Wire Range
            builder:addText(TEXT.WIRE_RANGE({range = itemInfo.wireLength}), attrF, "left")
        end
    end

    -- Padding
    builder:addPadding(descF:getHeight())

    -- Level
    builder:addText(TEXT.LEVEL_TOOLTIP({
        level = upgrade.level,
        maxLevel = maxLevel
    }), descF, "center")

    -- Price
    local price = g.getUpgTree():getUpgradePrice(upgrade)
    ---@type string[]
    local priceStrs = {}

    for _, resId in ipairs(g.RESOURCE_LIST) do
        local val = price[resId] or 0
        if val > 0 then
            local canAfford = g.getResource(resId) >= val
            priceStrs[#priceStrs+1] = helper.wrapRichtextColor(
                canAfford and g.COLORS.CAN_AFFORD or g.COLORS.CANT_AFFORD,
                "{"..resId.."}"..g.formatNumber(val)
            )
        end
    end

    if uinfo.getCustomRequirementText then
        local reqStr = uinfo.getCustomRequirementText(uinfo, upgrade)
        if reqStr and reqStr ~= "" then
            local isMet = true
            if uinfo.customRequirementMet then
                isMet = uinfo.customRequirementMet(uinfo, upgrade)
            end
            priceStrs[#priceStrs+1] = helper.wrapRichtextColor(
                isMet and g.COLORS.CAN_AFFORD or g.COLORS.CANT_AFFORD,
                reqStr
            )
        end
    end

    local priceText = table.concat(priceStrs, " ")
    if #priceStrs > 0 then
        builder:addText(priceText, priceF, "center")
    end

    builder:render()
end

return description
