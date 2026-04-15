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
        local p = (baseLoad - actualLoad) / baseLoad
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

---@param powerNetwork g.World.PowerNetwork
local function getPowerNetworkText(powerNetwork)
    local load = powerNetwork.totalLoad
    local power = powerNetwork.totalPower
    local s = g.formatNumber(load).."/"..g.formatNumber(power).."{bolt}"

    if power == 0 then
        s = helper.wrapRichtextColor(g.COLORS.UI.DEBUFF, s)
    elseif load > power then
        s = helper.wrapRichtextColor(g.COLORS.UI.WARNING, s)
    end

    return TEXT.TOTAL_LOAD_TOOLTIP({s = s})
end

---@param itemInfo g.ItemInfo
local function getItemPrice(itemInfo)
    if itemInfo.price <= 0 then
        return nil
    end

    local priceText = TEXT.PRICE_TOOLTIP({price = g.formatNumber(itemInfo.price)})
    if not g.canAfford({money = itemInfo.price}) then
        priceText = helper.wrapRichtextColor(g.COLORS.CANT_AFFORD, priceText)
    else
        priceText = helper.wrapRichtextColor(g.COLORS.CAN_AFFORD, priceText)
    end

    return priceText
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

    local builder = ui.TooltipBuilder("world", mx, my, safeArea)

    -- Title
    builder:addText(serverInfo.name, titleF, "center", titleFH)

    -- Category
    local computeNames = {}
    for _, jcname in ipairs(serverInfo.computePreference) do
        computeNames[#computeNames+1] = g.getJobCategoryName(jcname)
    end
    local categoryText = TEXT.CATEGORY_LIST({
        categories = table.concat(computeNames, TEXT.HORIZONTAL_LIST_SEPARATOR)
    })
    builder:addText(categoryText, descF, "center", titleFH)

    -- Description
    if serverInfo.description then
        builder:addPadding(descFH)
        builder:addText(serverInfo.description, descF, "center")
        builder:addPadding(descFH)
    end

    -- Attributes
    builder:addText(getItemLoadText(serverInfo, serverData), attrF, "left")
    if serverData.powerNetwork then
        builder:addText(getPowerNetworkText(serverData.powerNetwork), attrF, "left")
    end

    -- CPS
    local actualCPS = serverData.computePerSecond
    local baseCPS = serverInfo.computePerSecond
    local cpsText = TEXT.CPS_NUMBER({cps = g.formatNumber(actualCPS)})
    if actualCPS > baseCPS then
        local p = (actualCPS - baseCPS) / baseCPS
        cpsText = cpsText .. " " .. helper.wrapRichtextColor(g.COLORS.UI.BUFF, "(+" .. helper.round(p * 100, 2) .. "%)")
    elseif actualCPS < baseCPS then
        local p = (baseCPS - actualCPS) / baseCPS
        cpsText = cpsText .. " " .. helper.wrapRichtextColor(g.COLORS.UI.DEBUFF, "(-" .. helper.round(p * 100, 2) .. "%)")
    end
    builder:addText(cpsText, attrF, "left")

    -- Heat
    local heat = g.getTileHeat(serverData.tileX, serverData.tileY)
    local heatText = TEXT.SERVER_HEAT_NUMBER({
        heat = g.formatNumber(heat),
        max_heat = g.formatNumber(serverInfo.heatTolerance[2])
    })
    if heat > serverInfo.heatTolerance[2] then
        heatText = helper.wrapRichtextColor(g.COLORS.UI.DEBUFF, heatText .. " {emergency_heat}")
    elseif heat < serverInfo.heatTolerance[1] then
        heatText = helper.wrapRichtextColor(g.COLORS.UI.OVERCLOCKED, heatText .. " {snowflake}")
    end
    builder:addText(heatText, attrF, "left")

    -- Log
    local l = getLogMessages(serverData)
    if #l > 0 then
        builder:addPadding(descFH)
        for _, logmsg in ipairs(l) do
            builder:addText(logmsg, attrF, "center")
        end
    end

    -- Job
    if serverData.currentJob then
        local job = assert(serverData.currentJob)
        local jobData = {
            name = serverData.currentJob.name,
            computeText = g.formatNumber(job.computePower) .. " {dns}",
            outdataText = g.formatNumber(job.outputData) .. " {database}",
            earnText = "{money}" .. g.formatNumber(assert(job.resource.money)),
        }

        local _, lines = richtext.getWrap(jobData.name, attrF, 200)
        local nameHeight = lines * attrFH
        local PROGRESS_BAR_HEIGHT = 6
        local jobHeight = descFH * 2 + nameHeight + attrFH + PROGRESS_BAR_HEIGHT + descFH

        -- Ensure width fits job data
        local maxDataW = math.max(
            richtext.getWidth(jobData.computeText, attrF) + 8,
            richtext.getWidth(jobData.outdataText, attrF) + 8,
            richtext.getWidth(jobData.earnText, attrF) + 8
        )
        builder:ensureWidth(maxDataW)

        builder:addCustom(jobHeight, function(x, y, w)
            local OUTER_PAD = 2
            local curY = y + descFH
            love.graphics.rectangle("line", x - OUTER_PAD, curY - OUTER_PAD, w + OUTER_PAD * 2, (jobHeight - descFH) + OUTER_PAD * 2)

            richtext.printRich(jobData.name, attrF, x, curY, w, "center")
            curY = curY + nameHeight

            local computeR, dataR, moneyR = Kirigami(x, curY, w, attrFH):splitHorizontal(1, 1, 1)
            ui.printRichInRegion(jobData.computeText, attrF, computeR, true, "center")
            ui.printRichInRegion(jobData.outdataText, attrF, dataR, true, "center")
            ui.printRichInRegion(jobData.earnText, attrF, moneyR, true, "center")
            curY = curY + attrFH

            local cps = g.formatNumber(serverData.computePerSecond) .. " {dns}/s"
            if serverData.computePerSecond < serverInfo.computePerSecond then
                cps = helper.wrapRichtextColor(g.COLORS.UI.WARNING, cps)
            end
            local dpsVal = serverData.computePerSecond * job.outputData / job.computePower
            local dps = g.formatNumber(dpsVal) .. " {database}/s"
            if not serverData.activeOutput then
                dps = helper.wrapRichtextColor(g.COLORS.UI.DEBUFF, dps)
            end
            local cpsR, dpsR = Kirigami(x, curY, w, attrFH):splitHorizontal(1, 1)
            ui.printRichInRegion(cps, descF, cpsR, true, "center")
            ui.printRichInRegion(dps, descF, dpsR, true, "center")
            curY = curY + descFH

            local p = serverData.jobProgress / job.computePower
            love.graphics.printf(math.abs(helper.round(p * 100, 1)) .. "%", descF, x, curY, w, "center")
            curY = curY + descFH

            love.graphics.rectangle("fill", x, curY, w * p, PROGRESS_BAR_HEIGHT)
        end)
    end

    builder:render()
end

---@param dpData g.World.DataOutputData
---@param mx number
---@param my number
---@param safeArea kirigami.Region
function ItemTooltip.DPTooltipWorld(dpData, mx, my, safeArea)
    local dpInfo = g.getItemInfo(dpData.type, "data")
    local titleF = ItemTooltip.getTitleFont()
    local attrF = ItemTooltip.getAttrFont()
    local descF = ItemTooltip.getDescFont()
    local titleFH = titleF:getHeight()
    local descFH = descF:getHeight()

    local builder = ui.TooltipBuilder("world", mx, my, safeArea)

    -- Title
    builder:addText(dpInfo.name, titleF, "center", titleFH)

    -- Description
    if dpInfo.description then
        builder:addPadding(descFH)
        builder:addText(dpInfo.description, descF, "center")
        builder:addPadding(descFH)
    end

    -- Attributes
    builder:addText(getItemLoadText(dpInfo, dpData), attrF, "left")
    if dpData.powerNetwork then
        builder:addText(getPowerNetworkText(dpData.powerNetwork), attrF, "left")
    end
    builder:addText(TEXT.DPS_NUMBER({dps = g.formatNumber(dpData.dataPerSecond)}), attrF, "left")
        :addText(TEXT.WIRE_RANGE({range = dpInfo.wireLength}), attrF, "left")
        :addText(TEXT.WIRE_COUNT({s = #dpData.connectsServers}), attrF, "left")
        :addText(TEXT.WIRE_DPS({dps = g.formatNumber(dpInfo.wireDPS)}), attrF, "left")

    -- Log message
    local l = getLogMessages(dpData)
    if #l > 0 then
        builder:addPadding(descFH)

        for _, logmsg in ipairs(l) do
            builder:addText(logmsg, attrF, "center")
        end
    end

    builder:render()
end

---@param boosterData g.World.ItemData
---@param mx number
---@param my number
---@param safeArea kirigami.Region
function ItemTooltip.BoosterTooltipWorld(boosterData, mx, my, safeArea)
    local boosterInfo = g.getItemInfo(boosterData.type, "booster")
    local titleF = ItemTooltip.getTitleFont()
    local attrF = ItemTooltip.getAttrFont()
    local descF = ItemTooltip.getDescFont()
    local titleFH = titleF:getHeight()
    local descFH = descF:getHeight()

    local builder = ui.TooltipBuilder("world", mx, my, safeArea)

    -- Title
    builder:addText(boosterInfo.name, titleF, "center", titleFH)

    -- Description
    if boosterInfo.description then
        builder:addPadding(descFH)
        builder:addText(boosterInfo.description, descF, "center")
        builder:addPadding(descFH)
    end

    -- Attributes
    builder:addText(getItemLoadText(boosterInfo, boosterData), attrF, "left")
    if boosterData.powerNetwork then
        builder:addText(getPowerNetworkText(boosterData.powerNetwork), attrF, "left")
    end
    -- Effectivity
    local loadPercentage = worldutil.getLoadPercentage(boosterData)
    local effectivity = TEXT.EFFECTIVITY({effectivity = helper.round(loadPercentage * 100, 2)})
    if loadPercentage < 1 then
        effectivity = effectivity.." {bolt}"
        if loadPercentage < 0.75 then
            effectivity = helper.wrapRichtextColor(g.COLORS.UI.DEBUFF, effectivity)
        elseif loadPercentage < 1 then
            effectivity = helper.wrapRichtextColor(g.COLORS.UI.WARNING, effectivity)
        end
    end
    builder:addText(effectivity, attrF, "left")

    -- Log message
    local l = getLogMessages(boosterData)
    if #l > 0 then
        builder:addPadding(descFH)

        for _, logmsg in ipairs(l) do
            builder:addText(logmsg, attrF, "center")
        end
    end

    builder:render()
end

---@param diData g.World.DataInputData
---@param mx number
---@param my number
---@param safeArea kirigami.Region
function ItemTooltip.DITooltipWorld(diData, mx, my, safeArea)
    local diInfo = g.getItemInfo(diData.type, "indata")
    local titleF = ItemTooltip.getTitleFont()
    local attrF = ItemTooltip.getAttrFont()
    local descF = ItemTooltip.getDescFont()
    local titleFH = titleF:getHeight()
    local descFH = descF:getHeight()

    local builder = ui.TooltipBuilder("world", mx, my, safeArea)

    -- Title
    builder:addText(diInfo.name, titleF, "center", titleFH)

    -- Description
    if diInfo.description then
        builder:addPadding(descFH)
        builder:addText(diInfo.description, descF, "center")
        builder:addPadding(descFH)
    end

    -- Attributes
    builder:addText(getItemLoadText(diInfo, diData), attrF, "left")
    if diData.powerNetwork then
        builder:addText(getPowerNetworkText(diData.powerNetwork), attrF, "left")
    end
    builder:addText(TEXT.CATEGORY_LIST({
            categories = g.getJobCategoryName(diInfo.queuesJob)
        }), attrF, "left")
        :addText(TEXT.JOB_QUEUE({job = diInfo.maxJobQueue}), attrF, "left")
        :addText(TEXT.WIRE_RANGE({range = diInfo.wireLength}), attrF, "left")
        :addText(TEXT.WIRE_COUNT({s = #diData.connectsServers}), attrF, "left")

    -- Log message
    local l = getLogMessages(diData)
    if #l > 0 then
        builder:addPadding(descFH)

        for _, logmsg in ipairs(l) do
            builder:addText(logmsg, attrF, "center")
        end
    end

    builder:render()
end

---@param powerData g.World.PowerData
---@param x number relative to bottom center
---@param y number relative to bottom center
---@param safeArea kirigami.Region
function ItemTooltip.DrawPowerGenTooltip(powerData, x, y, safeArea)
    local powerGenInfo = g.getItemInfo(powerData.type, "powergen")
    local titleF = ItemTooltip.getTitleFont()
    local attrF = ItemTooltip.getAttrFont()
    local descF = ItemTooltip.getDescFont()
    local titleFH = titleF:getHeight()
    local descFH = descF:getHeight()

    local builder = ui.TooltipBuilder("world", x, y, safeArea)

    -- Title
    builder:addText(powerGenInfo.name, titleF, "center", titleFH)

    -- Description
    if powerGenInfo.description then
        builder:addPadding(descFH)
        builder:addText(powerGenInfo.description, descF, "center")
        builder:addPadding(descFH)
    end

    -- Attributes
    builder:addText(TEXT.PROVIDE_LOAD_TOOLTIP({load = powerData.power}), attrF, "left")
    if powerData.powerNetwork then
        builder:addText(getPowerNetworkText(powerData.powerNetwork), attrF, "left")
    end
    builder:addText(TEXT.WIRE_RANGE({range = powerGenInfo.wireLength}), attrF, "left")
        :addText(TEXT.WIRE_COUNT({s = #powerData.connectsTo}), attrF, "left")

    builder:render()
end


---@param powerData g.World.PowerData
---@param x number relative to bottom center
---@param y number relative to bottom center
---@param safeArea kirigami.Region
function ItemTooltip.DrawPowerRelayTooltip(powerData, x, y, safeArea)
    local powerRelayInfo = g.getItemInfo(powerData.type, "powerrelay")
    local titleF = ItemTooltip.getTitleFont()
    local attrF = ItemTooltip.getAttrFont()
    local descF = ItemTooltip.getDescFont()
    local titleFH = titleF:getHeight()
    local descFH = descF:getHeight()

    local builder = ui.TooltipBuilder("world", x, y, safeArea)

    -- Title
    builder:addText(powerRelayInfo.name, titleF, "center", titleFH)

    -- Description
    if powerRelayInfo.description then
        builder:addPadding(descFH)
        builder:addText(powerRelayInfo.description, descF, "center")
        builder:addPadding(descFH)
    end

    -- Attributes
    if powerData.powerNetwork then
        builder:addText(getPowerNetworkText(powerData.powerNetwork), attrF, "left")
    end
    builder:addText(TEXT.WIRE_RANGE({range = powerRelayInfo.wireLength}), attrF, "left")
        :addText(TEXT.WIRE_COUNT({s = #powerData.connectsTo}), attrF, "left")

    builder:render()
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
        ---@cast itemData g.World.DataOutputData
        ItemTooltip.DPTooltipWorld(itemData, x, y, safeArea)
    elseif cat == "indata" then
        ---@cast itemData g.World.DataInputData
        ItemTooltip.DITooltipWorld(itemData, x, y, safeArea)
    elseif cat == "booster" then
        ItemTooltip.BoosterTooltipWorld(itemData, x, y, safeArea)
    elseif cat == "powergen" then
        ---@cast itemData g.World.PowerData
        ItemTooltip.DrawPowerGenTooltip(itemData, x, y, safeArea)
    elseif cat == "powerrelay" then
        ---@cast itemData g.World.PowerData
        ItemTooltip.DrawPowerRelayTooltip(itemData, x, y, safeArea)
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
    local descFH = descF:getHeight()

    local builder = ui.TooltipBuilder("hud", x, y)

    -- Title
    builder:addText(serverInfo.name, titleF, "center", titleFH)

    -- Category
    local computeNames = {}
    for _, jcname in ipairs(serverInfo.computePreference) do
        computeNames[#computeNames+1] = g.getJobCategoryName(jcname)
    end
    local categoryText = TEXT.CATEGORY_LIST({
        categories = table.concat(computeNames, TEXT.HORIZONTAL_LIST_SEPARATOR)
    })
    builder:addText(categoryText, descF, "center", titleFH)

    -- Description
    if serverInfo.description then
        builder:addPadding(descFH)
        builder:addText(serverInfo.description, descF, "center")
        builder:addPadding(descFH)
    end

    -- Attributes
    local world = g.getMainWorld()
    -- Price
    local priceText = getItemPrice(serverInfo)
    if priceText then
        builder:addText(priceText, attrF, "left")
    end
    -- Load
    builder:addText(getItemLoadText(serverInfo), attrF, "left")
    -- CPS
    builder:addText(TEXT.CPS_NUMBER({cps = g.formatNumber(serverInfo.computePerSecond)}), attrF, "left")
    -- Heat tolerance
    builder:addText(TEXT.HEAT_TOLERANCE({
        min_heat = g.formatNumber(serverInfo.heatTolerance[1]),
        max_heat = g.formatNumber(serverInfo.heatTolerance[2])
    }), attrF, "left")

    builder:render()
end

---@param dpInfo g.DataOutInfo
---@param x number
---@param y number
function ItemTooltip.DPTooltipHUD(dpInfo, x, y)
    local titleF = ItemTooltip.getTitleFont()
    local attrF = ItemTooltip.getAttrFont()
    local descF = ItemTooltip.getDescFont()
    local titleFH = titleF:getHeight()
    local descFH = descF:getHeight()

    local builder = ui.TooltipBuilder("hud", x, y)

    -- Title
    builder:addText(dpInfo.name, titleF, "center", titleFH)

    -- Description
    if dpInfo.description then
        builder:addPadding(descFH)
        builder:addText(dpInfo.description, descF, "center")
        builder:addPadding(descFH)
    end

    -- Attributes
    local world = g.getMainWorld()
    -- Price
    local priceText = getItemPrice(dpInfo)
    if priceText then
        builder:addText(priceText, attrF, "left")
    end
    -- Load
    builder:addText(getItemLoadText(dpInfo), attrF, "left")
    -- DPS
    builder:addText(TEXT.DPS_NUMBER({dps = g.formatNumber(dpInfo.dataPerSecond)}), attrF, "left")
    -- Wire Range
    builder:addText(TEXT.WIRE_RANGE({range = dpInfo.wireLength}), attrF, "left")
    -- Wire DPS
    builder:addText(TEXT.WIRE_DPS({dps = g.formatNumber(dpInfo.wireDPS)}), attrF, "left")

    builder:render()
end

---@param diInfo g.DataInInfo
---@param x number relative to bottom center
---@param y number relative to bottom center
function ItemTooltip.DITooltipHUD(diInfo, x, y)
    local titleF = ItemTooltip.getTitleFont()
    local attrF = ItemTooltip.getAttrFont()
    local descF = ItemTooltip.getDescFont()
    local titleFH = titleF:getHeight()
    local descFH = descF:getHeight()

    local builder = ui.TooltipBuilder("hud", x, y)

    -- Title
    builder:addText(diInfo.name, titleF, "center", titleFH)

    -- Description
    if diInfo.description then
        builder:addPadding(descFH)
        builder:addText(diInfo.description, descF, "center")
        builder:addPadding(descFH)
    end

    -- Attributes
    local world = g.getMainWorld()
    -- Price
    local priceText = getItemPrice(diInfo)
    if priceText then
        builder:addText(priceText, attrF, "left")
    end
    -- Load
    builder:addText(getItemLoadText(diInfo), attrF, "left")
    -- Queued Job Category
    builder:addText(TEXT.CATEGORY_LIST({
        categories = g.getJobCategoryName(diInfo.queuesJob)
    }), attrF, "left")
    -- Added Job Queue
    builder:addText(TEXT.JOB_QUEUE({job = diInfo.maxJobQueue}), attrF, "left")
    -- Wire Range
    builder:addText(TEXT.WIRE_RANGE({range = diInfo.wireLength}), attrF, "left")

    builder:render()
end

---@param boosterInfo g.BoosterInfo
---@param x number
---@param y number
function ItemTooltip.BoosterTooltipHUD(boosterInfo, x, y)
    local titleF = ItemTooltip.getTitleFont()
    local attrF = ItemTooltip.getAttrFont()
    local descF = ItemTooltip.getDescFont()
    local titleFH = titleF:getHeight()
    local descFH = descF:getHeight()

    local builder = ui.TooltipBuilder("hud", x, y)

    -- Title
    builder:addText(boosterInfo.name, titleF, "center", titleFH)

    -- Description
    if boosterInfo.description then
        builder:addPadding(descFH)
        builder:addText(boosterInfo.description, descF, "center")
        builder:addPadding(descFH)
    end

    -- Attributes
    local world = g.getMainWorld()
    -- Price
    local priceText = getItemPrice(boosterInfo)
    if priceText then
        builder:addText(priceText, attrF, "left")
    end
    -- Load
    builder:addText(getItemLoadText(boosterInfo), attrF, "left")

    builder:render()
end

---@param powerGenInfo g.PowerGenInfo
---@param x number
---@param y number
function ItemTooltip.PowerGenTooltipHUD(powerGenInfo, x, y)
    local titleF = ItemTooltip.getTitleFont()
    local attrF = ItemTooltip.getAttrFont()
    local descF = ItemTooltip.getDescFont()
    local titleFH = titleF:getHeight()
    local descFH = descF:getHeight()

    local builder = ui.TooltipBuilder("hud", x, y)

    -- Title
    builder:addText(powerGenInfo.name, titleF, "center", titleFH)

    -- Description
    if powerGenInfo.description then
        builder:addPadding(descFH)
        builder:addText(powerGenInfo.description, descF, "center")
        builder:addPadding(descFH)
    end

    -- Attributes
    -- Price
    local priceText = getItemPrice(powerGenInfo)
    if priceText then
        builder:addText(priceText, attrF, "left")
    end
    -- Load
    builder:addText(TEXT.PROVIDE_LOAD_TOOLTIP({load = powerGenInfo.power}), attrF, "left")
        :addText(TEXT.WIRE_RANGE({range = powerGenInfo.wireLength}), attrF, "left")

    builder:render()
end

---@param powerRelayInfo g.PowerRelayInfo
---@param x number
---@param y number
function ItemTooltip.PowerRelayTooltipHUD(powerRelayInfo, x, y)
    local titleF = ItemTooltip.getTitleFont()
    local attrF = ItemTooltip.getAttrFont()
    local descF = ItemTooltip.getDescFont()
    local titleFH = titleF:getHeight()
    local descFH = descF:getHeight()

    local builder = ui.TooltipBuilder("hud", x, y)

    -- Title
    builder:addText(powerRelayInfo.name, titleF, "center", titleFH)

    -- Description
    if powerRelayInfo.description then
        builder:addPadding(descFH)
        builder:addText(powerRelayInfo.description, descF, "center")
        builder:addPadding(descFH)
    end

    -- Attributes
    -- Price
    local priceText = getItemPrice(powerRelayInfo)
    if priceText then
        builder:addText(priceText, attrF, "left")
    end
    -- Range
    builder:addText(TEXT.WIRE_RANGE({range = powerRelayInfo.wireLength}), attrF, "left")

    builder:render()
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
        ---@cast itemInfo g.DataOutInfo
        ItemTooltip.DPTooltipHUD(itemInfo, x, y)
    elseif itemInfo.category == "indata" then
        ---@cast itemInfo g.DataInInfo
        ItemTooltip.DITooltipHUD(itemInfo, x, y)
    elseif itemInfo.category == "booster" then
        ---@cast itemInfo g.BoosterInfo
        ItemTooltip.BoosterTooltipHUD(itemInfo, x, y)
    elseif itemInfo.category == "powergen" then
        ---@cast itemInfo g.PowerGenInfo
        ItemTooltip.PowerGenTooltipHUD(itemInfo, x, y)
    elseif itemInfo.category == "powerrelay" then
        ---@cast itemInfo g.PowerRelayInfo
        ItemTooltip.PowerRelayTooltipHUD(itemInfo, x, y)
    else
        error("unreachable category")
    end
    col:pop()
end

return ItemTooltip
