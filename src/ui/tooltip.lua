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
    local attrF = g.getMainFont(13)
    local descF = g.getMainFont(9)
    local titleFH = titleF:getHeight()
    local attrFH = attrF:getHeight()
    local descFH = descF:getHeight()
    local width, height = 120, 0

    -- Pass 1: Compute tooltip sizes

    -- Title
    local titleHeight
    do
        local w, l = richtext.getWrap(serverInfo.name, titleF, MAX_TOOLTIP_WIDTH)
        width = helper.clamp(width, w, MAX_TOOLTIP_WIDTH)
        titleHeight = l * titleFH
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
        categoryHeight = l * titleFH
        height = height + categoryHeight
    end

    -- Description
    local descriptionHeight = 0
    local descriptionText = nil
    if serverInfo.description then
        -- Description is padded with 2 empty lines
        descriptionText = "\n"..serverInfo.description.."\n"
        local w, l = richtext.getWrap(descriptionText, descF, MAX_TOOLTIP_WIDTH)
        width = helper.clamp(width, w, MAX_TOOLTIP_WIDTH)
        descriptionHeight = l * descFH
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
        at[#at+1] = "" -- padding

        attributesText = table.concat(at, "\n")
        local w, l = richtext.getWrap(attributesText, attrF, MAX_TOOLTIP_WIDTH)
        width = helper.clamp(width, w, MAX_TOOLTIP_WIDTH)
        attributesHeight = l * attrFH
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
            local w, lines = richtext.getWrap(logText, attrF, MAX_TOOLTIP_WIDTH)
            width = helper.clamp(width, w, MAX_TOOLTIP_WIDTH)
            logHeight = lines * attrFH
            height = height + logHeight
        end
    end

    -- Job info
    local jobData, jobHeight = nil, 0
    local PROGRESS_BAR_HEIGHT = 6
    if serverData.currentJob then
        local job = assert(serverData.currentJob)
        jobData = {
            name = serverData.currentJob.name,
            nameHeight = 0,
            computeText = g.formatNumber(job.computePower).." {dns}",
            outdataText = g.formatNumber(job.outputData).." {database}",
            earnText = "{money}"..g.formatNumber(assert(job.resource.money)),
        }

        -- Job name
        do
            local w, l = richtext.getWrap(jobData.name, attrF, MAX_TOOLTIP_WIDTH)
            width = helper.clamp(width, w, MAX_TOOLTIP_WIDTH)
            jobData.nameHeight = l * attrFH
        end
        -- Adjust width to fit data info
        do
            local w = math.max(
                richtext.getWidth(jobData.computeText, attrF),
                richtext.getWidth(jobData.outdataText, attrF),
                richtext.getWidth(jobData.earnText, attrF)
            ) + 4 -- +4 for padding
            width = helper.clamp(width, w, MAX_TOOLTIP_WIDTH)
        end

        -- Added heights:
        -- padding (descF height)
        -- Job name (attrF height * line)
        -- Job data info (attrF height)
        -- Final CPS (descF height)
        -- Percentage value (descF height)
        -- progress bar height (PROGRESS_BAR_HEIGHT)
        jobHeight = descFH * 2
            + jobData.nameHeight
            + attrFH
            + PROGRESS_BAR_HEIGHT
        height = height + jobHeight + descFH
    end

    -- Generate region now
    local tdrawableR, tcntR = ui.getTooltipRegion(mx, my, width, height, safeArea)
    ui.Tooltip(tdrawableR, objects.Color.BLACK, objects.Color.WHITE)

    -- Pass 2: Draw the tooltip
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
    if descriptionText then
        richtext.printRich(descriptionText, descF, tcntR.x, tcntR.y + height, tcntR.w, "center")
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
    -- Draw job info
    if jobData then
        --[[
        TODO: Modify how tooltip is rendered.
        For sake of moving fast, let's just do rectangle for now.

        Oli suggestion:
        * Make it fixed-width
        * Make the job info "glued"

        My suggestion: Text size probably needs adjustment.
        ]]
        local OUTER_PAD = 2
        height = height + descFH -- padding
        love.graphics.rectangle("line", tcntR.x - OUTER_PAD, tcntR.y + height - OUTER_PAD, tcntR.w + OUTER_PAD * 2, jobHeight + OUTER_PAD * 2)

        -- Job name
        richtext.printRich(jobData.name, attrF, tcntR.x, tcntR.y + height, tcntR.w, "center")
        height = height + jobData.nameHeight
        -- Job info
        local computeR, dataR, moneyR = Kirigami(tcntR.x, tcntR.y + height, tcntR.w, attrFH):splitHorizontal(1, 1, 1)
        ui.printRichInRegion(jobData.computeText, attrF, computeR, true, "center")
        ui.printRichInRegion(jobData.outdataText, attrF, dataR, true, "center")
        ui.printRichInRegion(jobData.earnText, attrF, moneyR, true, "center")
        height = height + attrFH
        -- Final CPS
        local cps = g.formatNumber(serverData.finalCPS).." {dns}/s"
        if serverData.finalCPS < serverData.computePerSecond then
            cps = helper.wrapRichtextColor(g.COLORS.UI.WARNING, cps)
        end
        richtext.printRich(cps, descF, tcntR.x, tcntR.y + height, tcntR.w, "center")
        height = height + descFH
        -- Progress percentage
        local job = assert(serverData.currentJob)
        local p = serverData.jobProgress / job.computePower
        love.graphics.printf(helper.round(p * 100, 1).."%", descF, tcntR.x, tcntR.y + height, tcntR.w, "center")
        height = height + descFH
        -- Progress bar
        love.graphics.rectangle("fill", tcntR.x, tcntR.y + height, tcntR.w * p, PROGRESS_BAR_HEIGHT)
        height = height + descFH
    end
end

---@param dpData g.World.DataProcessorData
---@param mx number
---@param my number
---@param safeArea kirigami.Region
function ItemTooltip.DPTooltipWorld(dpData, mx, my, safeArea)
    local dpInfo = g.getItemInfo(dpData.type, "data")
    local titleF = g.getMainFont(16)
    local attrF = g.getMainFont(13)
    local descF = g.getMainFont(9)
    local titleFH = titleF:getHeight()
    local attrFH = attrF:getHeight()
    local descFH = descF:getHeight()
    local width, height = 120, 0

    -- Pass 1: Compute tooltip sizes

    -- Title
    local titleHeight
    do
        local w, l = richtext.getWrap(dpInfo.name, titleF, MAX_TOOLTIP_WIDTH)
        width = helper.clamp(width, w, MAX_TOOLTIP_WIDTH)
        titleHeight = l * titleFH
        height = height + titleHeight
    end

    -- Description
    local descriptionText, descriptionHeight
    if dpInfo.description then
        descriptionText = "\n"..dpInfo.description.."\n"
        local w, l = richtext.getWrap(descriptionText, descF, MAX_TOOLTIP_WIDTH)
        width = helper.clamp(width, w, MAX_TOOLTIP_WIDTH)
        descriptionHeight = l * descFH
        height = height + descriptionHeight
    end

    -- Attributes
    local attributesText, attributesHeight
    do
        local attributes = {}
        attributes[#attributes+1] = TEXT.DPS_NUMBER({dps = g.formatNumber(dpData.dataPerSecond)})
        attributes[#attributes+1] = TEXT.WIRE_RANGE({range = dpInfo.wireCount})
        local wcattr = TEXT.WIRE_COUNT({s = #dpData.connectsServers})
        if dpInfo.wireCount then
            wcattr = TEXT.WIRE_COUNT({s = #dpData.connectsServers.."/"..dpInfo.wireCount})
            if #dpData.connectsServers >= dpInfo.wireCount then
                wcattr = helper.wrapRichtextColor(g.COLORS.UI.DEBUFF, wcattr)
            end
        else
            wcattr = TEXT.WIRE_COUNT({s = #dpData.connectsServers})
        end
        attributes[#attributes+1] = wcattr

        attributesText = table.concat(attributes, "\n")
        local w, l = richtext.getWrap(attributesText, attrF, MAX_TOOLTIP_WIDTH)
        width = helper.clamp(width, w, MAX_TOOLTIP_WIDTH)
        attributesHeight = l * attrFH
        height = height + attributesHeight
    end

    -- Generate region now
    local tdrawableR, tcntR = ui.getTooltipRegion(mx, my, width, height, safeArea)
    ui.Tooltip(tdrawableR, objects.Color.BLACK, objects.Color.WHITE)

    -- Pass 2: Draw the tooltip
    height = 0
    -- Draw name
    do
        richtext.printRich(dpInfo.name, titleF, tcntR.x, tcntR.y + height, tcntR.w, "center")
        height = height + titleHeight
    end
    -- Draw description
    if descriptionText then
        richtext.printRich(descriptionText, descF, tcntR.x, tcntR.y + height, tcntR.w, "center")
        height = height + descriptionHeight
    end
    -- Draw attributes
    do
        richtext.printRich(attributesText, attrF, tcntR.x, tcntR.y + height, tcntR.w, "left")
        height = height + attributesHeight
    end
end

---@param itemData g.World.ItemData
---@param mx number
---@param my number
---@param safeArea kirigami.Region
function ItemTooltip.BoosterTooltipWorld(itemData, mx, my, safeArea)
    local world = g.getMainWorld()
    local boosterInfo = g.getItemInfo(itemData.type, "booster")
    local titleF = g.getMainFont(16)
    local attrF = g.getMainFont(13)
    local descF = g.getMainFont(9)
    local titleFH = titleF:getHeight()
    local attrFH = attrF:getHeight()
    local descFH = descF:getHeight()
    local width, height = 120, 0

    -- Pass 1: Compute tooltip sizes

    -- Title
    local titleHeight
    do
        local w, l = richtext.getWrap(boosterInfo.name, titleF, MAX_TOOLTIP_WIDTH)
        width = helper.clamp(width, w, MAX_TOOLTIP_WIDTH)
        titleHeight = l * titleFH
        height = height + titleHeight
    end

    -- Description
    local descriptionText, descriptionHeight
    if boosterInfo.description then
        descriptionText = "\n"..boosterInfo.description.."\n"
        local w, l = richtext.getWrap(descriptionText, descF, MAX_TOOLTIP_WIDTH)
        width = helper.clamp(width, w, MAX_TOOLTIP_WIDTH)
        descriptionHeight = l * descFH
        height = height + descriptionHeight
    end

    -- Effectivity
    local effectivityText, effectivityHeight
    do
        effectivityText = TEXT.EFFECTIVITY({effectivity = helper.round(world.loadPercentage * 100, 2)})
        if world.loadPercentage < 1 then
            effectivityText = effectivityText.." {bolt}"
            if world.loadPercentage < 0.75 then
                effectivityText = helper.wrapRichtextColor(g.COLORS.UI.DEBUFF, effectivityText)
            elseif world.loadPercentage < 1 then
                effectivityText = helper.wrapRichtextColor(g.COLORS.UI.WARNING, effectivityText)
            end
        end

        local w, l = richtext.getWrap(effectivityText, attrF, MAX_TOOLTIP_WIDTH)
        width = helper.clamp(width, w, MAX_TOOLTIP_WIDTH)
        effectivityHeight = l * attrFH
        height = height + effectivityHeight
    end

    -- Generate region now
    local tdrawableR, tcntR = ui.getTooltipRegion(mx, my, width, height, safeArea)
    ui.Tooltip(tdrawableR, objects.Color.BLACK, objects.Color.WHITE)

    -- Pass 2: Draw the tooltip
    height = 0
    -- Draw name
    do
        richtext.printRich(boosterInfo.name, titleF, tcntR.x, tcntR.y + height, tcntR.w, "center")
        height = height + titleHeight
    end
    -- Draw description
    if descriptionText then
        richtext.printRich(descriptionText, descF, tcntR.x, tcntR.y + height, tcntR.w, "center")
        height = height + descriptionHeight
    end
    -- Draw attributes
    do
        richtext.printRich(effectivityText, attrF, tcntR.x, tcntR.y + height, tcntR.w, "left")
        height = height + effectivityHeight
    end
end

---@param itemData g.World.ItemData
---@param x number relative to bottom center
---@param y number relative to bottom center
---@param safeArea kirigami.Region
function ItemTooltip.DrawWorldTooltip(itemData, x, y, safeArea)
    local _, cat = g.getItemInfo(itemData.type)
    local col = gsman.setColor(1, 1, 1)
    if cat == "server" then
        ---@cast itemData g.World.ServerData
        ItemTooltip.ServerTooltipWorld(itemData, x, y, safeArea)
    elseif cat == "data" then
        ---@cast itemData g.World.DataProcessorData
        ItemTooltip.DPTooltipWorld(itemData, x, y, safeArea)
    elseif cat == "booster" then
        ItemTooltip.BoosterTooltipWorld(itemData, x, y, safeArea)
    else
        error("unreachable category")
    end
    col:pop()
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
