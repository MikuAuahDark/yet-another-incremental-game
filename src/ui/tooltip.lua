---@class ui.ItemTooltip
local ItemTooltip = {}

local MAX_TOOLTIP_WIDTH = 200



---@param itemInfo g.ItemInfo
---@param itemData g.World.ItemData?
local function getItemLoadText(itemInfo, itemData)
    local baseLoad = itemInfo.load
    local actualLoad
    if itemData then
        actualLoad = itemData.load
    else
        actualLoad = g.getMainWorld():computeLoadModifier(itemInfo)
    end

    local loadText = TEXT.LOAD_TOOLTIP({load = g.formatNumber(actualLoad)})
    if actualLoad > baseLoad then
        local p = (actualLoad - baseLoad) / baseLoad
        loadText = loadText.." "..helper.wrapRichtextColor(g.COLORS.UI.DEBUFF, "(+"..helper.round(p * 100, 2).."%)")
    elseif actualLoad < baseLoad then
        local p = (actualLoad - baseLoad) / baseLoad
        loadText = loadText.." "..helper.wrapRichtextColor(g.COLORS.UI.BUFF, "(-"..helper.round(p * 100, 2).."%)")
    end

    return loadText
end


---@param itemData g.World.ItemData
local function getLogMessages(itemData)
    local problems = g.getItemProblems(itemData)
    ---@type string[]
    local logMessages = {}

    for _, v in ipairs(problems) do
        local pinfo = g.getItemProblemInfo(v)
        local col = pinfo.error and g.COLORS.UI.DEBUFF or g.COLORS.UI.WARNING
        logMessages[#logMessages+1] = helper.wrapRichtextColor(col, "{"..pinfo.icon.."} "..pinfo.text)
    end

    return logMessages
end

-- Putting this here so font sizes can be changed in one place
function ItemTooltip.getTitleFont() return g.getMainFont(16) end
function ItemTooltip.getAttrFont() return g.getMainFont(13) end
function ItemTooltip.getDescFont() return g.getMainFont(10) end



---@param serverData g.World.ServerData
---@param mx number
---@param my number
---@param safeArea kirigami.Region
function ItemTooltip.ServerTooltipWorld(serverData, mx, my, safeArea)
    local serverInfo = g.getItemInfo(serverData.type, "server")
    local titleF = ItemTooltip.getTitleFont()
    local attrF = ItemTooltip.getAttrFont()
    local descF = ItemTooltip.getDescFont()
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
        -- Load
        at[#at+1] = getItemLoadText(serverInfo, serverData)
        -- CPS
        local actualCPS = serverData.computePerSecond
        local baseCPS = serverInfo.computePerSecond
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
            heat = g.formatNumber(heat),
            max_heat = g.formatNumber(serverInfo.heatTolerance[2])
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
        local l = getLogMessages(serverData)

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
            -- +8 for padding
            local w = math.max(
                richtext.getWidth(jobData.computeText, attrF) + 8,
                richtext.getWidth(jobData.outdataText, attrF) + 8,
                richtext.getWidth(jobData.earnText, attrF) + 8
            )
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
    local titleF = ItemTooltip.getTitleFont()
    local attrF = ItemTooltip.getAttrFont()
    local descF = ItemTooltip.getDescFont()
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
        local at = {}
        at[#at+1] = getItemLoadText(dpInfo, dpData)
        at[#at+1] = TEXT.DPS_NUMBER({dps = g.formatNumber(dpData.dataPerSecond)})
        at[#at+1] = TEXT.WIRE_RANGE({range = dpInfo.wireLength})
        local wcattr
        if dpInfo.wireCount then
            wcattr = TEXT.WIRE_COUNT({s = #dpData.connectsServers.."/"..dpInfo.wireCount})
            if #dpData.connectsServers >= dpInfo.wireCount then
                wcattr = helper.wrapRichtextColor(g.COLORS.UI.DEBUFF, wcattr)
            end
        else
            wcattr = TEXT.WIRE_COUNT({s = #dpData.connectsServers})
        end
        at[#at+1] = wcattr

        attributesText = table.concat(at, "\n")
        local w, l = richtext.getWrap(attributesText, attrF, MAX_TOOLTIP_WIDTH)
        width = helper.clamp(width, w, MAX_TOOLTIP_WIDTH)
        attributesHeight = l * attrFH
        height = height + attributesHeight
    end

    -- Log message
    local logText, logHeight = nil, 0
    do
        local l = getLogMessages(dpData)

        if #l > 0 then
            logText = table.concat(l, "\n")
            local w, lines = richtext.getWrap(logText, attrF, MAX_TOOLTIP_WIDTH)
            width = helper.clamp(width, w, MAX_TOOLTIP_WIDTH)
            logHeight = lines * attrFH
            height = height + logHeight
        end
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
    -- Draw log message
    if logText then
        local r = Kirigami(tcntR.x, tcntR.y + height, tcntR.w, logHeight)
        ui.printRichInRegion(logText, attrF, r, true, "center")
        height = height + logHeight
    end
end

---@param boosterData g.World.ItemData
---@param mx number
---@param my number
---@param safeArea kirigami.Region
function ItemTooltip.BoosterTooltipWorld(boosterData, mx, my, safeArea)
    local world = g.getMainWorld()
    local boosterInfo = g.getItemInfo(boosterData.type, "booster")
    local titleF = ItemTooltip.getTitleFont()
    local attrF = ItemTooltip.getAttrFont()
    local descF = ItemTooltip.getDescFont()
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

    -- Attributes
    local attributesText, attributesHeight
    do
        local at = {}
        -- Load
        at[#at+1] = getItemLoadText(boosterInfo, boosterData)
        -- Effectivity
        local effectivity = TEXT.EFFECTIVITY({effectivity = helper.round(world.loadPercentage * 100, 2)})
        if world.loadPercentage < 1 then
            effectivity = effectivity.." {bolt}"
            if world.loadPercentage < 0.75 then
                effectivity = helper.wrapRichtextColor(g.COLORS.UI.DEBUFF, effectivity)
            elseif world.loadPercentage < 1 then
                effectivity = helper.wrapRichtextColor(g.COLORS.UI.WARNING, effectivity)
            end
        end
        at[#at+1] = effectivity

        attributesText = table.concat(at, "\n")
        local w, l = richtext.getWrap(attributesText, attrF, MAX_TOOLTIP_WIDTH)
        width = helper.clamp(width, w, MAX_TOOLTIP_WIDTH)
        attributesHeight = l * attrFH
        height = height + attributesHeight
    end

    -- Log message
    local logText, logHeight = nil, 0
    do
        local l = getLogMessages(boosterData)

        if #l > 0 then
            logText = table.concat(l, "\n")
            local w, lines = richtext.getWrap(logText, attrF, MAX_TOOLTIP_WIDTH)
            width = helper.clamp(width, w, MAX_TOOLTIP_WIDTH)
            logHeight = lines * attrFH
            height = height + logHeight
        end
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
    local titleF = ItemTooltip.getTitleFont()
    local attrF = ItemTooltip.getAttrFont()
    local descF = ItemTooltip.getDescFont()
    local titleFH = titleF:getHeight()
    local attrFH = attrF:getHeight()
    local descFH = descF:getHeight()
    local width, height = 0, 0

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
    local descriptionText, descriptionHeight = nil, 0
    if serverInfo.description then
        descriptionText = "\n"..serverInfo.description.."\n"
        local w, l = richtext.getWrap(descriptionText, descF, MAX_TOOLTIP_WIDTH)
        width = helper.clamp(width, w, MAX_TOOLTIP_WIDTH)
        descriptionHeight = l * descFH
        height = height + descriptionHeight
    end

    -- Attributes
    local attributesText, attributesHeight
    do
        local at = {}
        local world = g.getMainWorld()
        -- Load
        local load = world:computeLoadModifier(serverInfo)
        local loadText = TEXT.LOAD_TOOLTIP({load = load})
        if (world.currentLoad + load) > g.stats.MaxLoad then
            loadText = helper.wrapRichtextColor(g.COLORS.UI.WARNING, loadText)
        end
        at[#at+1] = loadText
        -- CPS
        at[#at+1] = TEXT.CPS_NUMBER({cps = g.formatNumber(serverInfo.computePerSecond)})
        -- Heat tolerance
        at[#at+1] = TEXT.HEAT_TOLERANCE({
            min_heat = g.formatNumber(serverInfo.heatTolerance[1]),
            max_heat = g.formatNumber(serverInfo.heatTolerance[2])
        })

        attributesText = table.concat(at, "\n")
        local w, l = richtext.getWrap(attributesText, attrF, MAX_TOOLTIP_WIDTH)
        width = helper.clamp(width, w, MAX_TOOLTIP_WIDTH)
        attributesHeight = l * attrFH
        height = height + attributesHeight
    end

    -- Generate region
    local tdrawableR, tcntR = ui.getTooltipRegion(x - width / 2, y - height, width, height)
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
end

---@param dpInfo g.DataInfo
---@param x number
---@param y number
function ItemTooltip.DPTooltipHUD(dpInfo, x, y)
    local titleF = ItemTooltip.getTitleFont()
    local attrF = ItemTooltip.getAttrFont()
    local descF = ItemTooltip.getDescFont()
    local titleFH = titleF:getHeight()
    local attrFH = attrF:getHeight()
    local descFH = descF:getHeight()
    local width, height = 0, 0

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
    local descriptionText, descriptionHeight = nil, 0
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
        local at = {}
        local world = g.getMainWorld()
        -- Load
        local load = world:computeLoadModifier(dpInfo)
        local loadText = TEXT.LOAD_TOOLTIP({load = load})
        if (world.currentLoad + load) > g.stats.MaxLoad then
            loadText = helper.wrapRichtextColor(g.COLORS.UI.WARNING, loadText)
        end
        at[#at+1] = loadText
        -- DPS
        at[#at+1] = TEXT.DPS_NUMBER({dps = g.formatNumber(dpInfo.dataPerSecond)})
        -- Wire Range
        at[#at+1] = TEXT.WIRE_RANGE({range = dpInfo.wireLength})
        -- Wire count
        if dpInfo.wireCount then
            at[#at+1] = TEXT.MAX_WIRE_COUNT({s = dpInfo.wireCount})
        end

        attributesText = table.concat(at, "\n")
        local w, l = richtext.getWrap(attributesText, attrF, MAX_TOOLTIP_WIDTH)
        width = helper.clamp(width, w, MAX_TOOLTIP_WIDTH)
        attributesHeight = l * attrFH
        height = height + attributesHeight
    end

    -- Generate region
    local tdrawableR, tcntR = ui.getTooltipRegion(x - width / 2, y - height, width, height)
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

---@param boosterInfo g.BoosterInfo
---@param x number
---@param y number
function ItemTooltip.BoosterTooltipHUD(boosterInfo, x, y)
    local titleF = ItemTooltip.getTitleFont()
    local attrF = ItemTooltip.getAttrFont()
    local descF = ItemTooltip.getDescFont()
    local titleFH = titleF:getHeight()
    local attrFH = attrF:getHeight()
    local descFH = descF:getHeight()
    local width, height = 0, 0

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
    local descriptionText, descriptionHeight = nil, 0
    if boosterInfo.description then
        descriptionText = "\n"..boosterInfo.description.."\n"
        local w, l = richtext.getWrap(descriptionText, descF, MAX_TOOLTIP_WIDTH)
        width = helper.clamp(width, w, MAX_TOOLTIP_WIDTH)
        descriptionHeight = l * descFH
        height = height + descriptionHeight
    end

    -- Attributes
    local attributesText, attributesHeight
    do
        local at = {}
        local world = g.getMainWorld()
        -- Load
        local load = world:computeLoadModifier(boosterInfo)
        local loadText = TEXT.LOAD_TOOLTIP({load = load})
        if (world.currentLoad + load) > g.stats.MaxLoad then
            loadText = helper.wrapRichtextColor(g.COLORS.UI.WARNING, loadText)
        end
        at[#at+1] = loadText

        attributesText = table.concat(at, "\n")
        local w, l = richtext.getWrap(attributesText, attrF, MAX_TOOLTIP_WIDTH)
        width = helper.clamp(width, w, MAX_TOOLTIP_WIDTH)
        attributesHeight = l * attrFH
        height = height + attributesHeight
    end

    -- Generate region
    local tdrawableR, tcntR = ui.getTooltipRegion(x - width / 2, y - height, width, height)
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
        richtext.printRich(attributesText, attrF, tcntR.x, tcntR.y + height, tcntR.w, "left")
        height = height + attributesHeight
    end
end

---@param itemInfo g.ItemInfo
---@param x number
---@param y number
function ItemTooltip.DrawHUDTooltip(itemInfo, x, y)
    local col = gsman.setColor(1, 1, 1)
    if itemInfo.category == "server" then
        ---@cast itemInfo g.ServerInfo
        ItemTooltip.ServerTooltipHUD(itemInfo, x, y)
    elseif itemInfo.category == "data" then
        ---@cast itemInfo g.DataInfo
        ItemTooltip.DPTooltipHUD(itemInfo, x, y)
    elseif itemInfo.category == "booster" then
        ---@cast itemInfo g.BoosterInfo
        ItemTooltip.BoosterTooltipHUD(itemInfo, x, y)
    else
        error("unreachable category")
    end
    col:pop()
end

return ItemTooltip
