---@class ui.ItemTooltip
local ItemTooltip = {}


---@param itemInfo g.ItemInfo<any>
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
---@param builder ui.TooltipBuilder
local function addLogMessages(itemData, builder)
    local problems = g.getItemProblems(itemData)
    local attrF = ItemTooltip.getAttrFont()

    for _, v in ipairs(problems) do
        local pinfo = g.getItemProblemInfo(v)
        local col = pinfo.error and g.COLORS.UI.DEBUFF or g.COLORS.UI.WARNING
        builder:addText(helper.wrapRichtextColor(col, "{"..pinfo.icon.."} "..pinfo.text), attrF, "center")
    end
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
    else
        s = helper.wrapRichtextColor(g.COLORS.UI.BUFF, s)
    end

    return TEXT.TOTAL_LOAD_TOOLTIP({s = s})
end

---@param itemInfo g.ItemInfo<any>
---@deprecated
local function getItemPrice(itemInfo)
    return nil
end

---@param dpInfo g.DataOutInfo
local function getDPS(dpInfo)
    local dps = g.getProperty("getDataThroughput", dpInfo.dataPerSecond, 1, dpInfo)
    local dpsText = helper.wrapRichtextColor(g.COLORS.UI.TEXT_DPS, TEXT.DPS_NUMBER({dps = g.formatNumber(dps)}))
    if dps > dpInfo.dataPerSecond then
        local p = (dps - dpInfo.dataPerSecond) / dpInfo.dataPerSecond
        dpsText = dpsText.." "..helper.wrapRichtextColor(g.COLORS.UI.BUFF, "("..helper.round(p * 100, 2).."%)")
    elseif dps < dpInfo.dataPerSecond then
        local p = (dpInfo.dataPerSecond - dps) / dpInfo.dataPerSecond
        dpsText = dpsText.." "..helper.wrapRichtextColor(g.COLORS.UI.DEBUFF, "("..helper.round(p * 100, 2).."%)")
    end
    return dpsText
end

---@param dpInfo g.DataOutInfo
local function getWireDPS(dpInfo)
    local dps = g.getProperty("getWireThroughput", dpInfo.wireDPS, 1, dpInfo)

    local dpsText = TEXT.WIRE_DPS({dps = g.formatNumber(dps)})
    if dps > dpInfo.wireDPS then
        local p = (dps - dpInfo.wireDPS) / dpInfo.wireDPS
        dpsText = dpsText.." "..helper.wrapRichtextColor(g.COLORS.UI.BUFF, "(+"..helper.round(p * 100, 2).."%)")
    elseif dps < dpInfo.wireDPS then
        local p = (dpInfo.wireDPS - dps) / dpInfo.wireDPS
        dpsText = dpsText.." "..helper.wrapRichtextColor(g.COLORS.UI.DEBUFF, "(-"..helper.round(p * 100, 2).."%)")
    end

    return dpsText
end

---@param powerGenInfo g.PowerGenInfo
local function getGeneratorOutput(powerGenInfo)
    local power = g.getProperty("getGeneratorLoad", powerGenInfo.power, 1, powerGenInfo)
    local powerText = TEXT.PROVIDE_LOAD_TOOLTIP({load = g.formatNumber(power)})
    if power > powerGenInfo.power then
        local p = (power - powerGenInfo.power) / powerGenInfo.power
        powerText = powerText.." "..helper.wrapRichtextColor(g.COLORS.UI.BUFF, "(+"..helper.round(p * 100, 2).."%)")
    elseif power < powerGenInfo.power then
        local p = (powerGenInfo.power - power) / powerGenInfo.power
        powerText = powerText.." "..helper.wrapRichtextColor(g.COLORS.UI.DEBUFF, "(-"..helper.round(p * 100, 2).."%)")
    end
    return powerText
end

---@param info g.ServerInfo|g.DataInInfo
local function getServerDataInputDisplayName(info)
    local ctype
    if info.computeType then
        ctype = info.computeType
    else
        ctype = info.queuesJob
    end
    local ctypeup = ctype:upper()
    local symbol = "{COLORS_JOBS_"..ctypeup.."}{"..g.getJobCategoryInfo(ctype).symbol.."}{/COLORS_JOBS_"..ctypeup.."}"
    return symbol..info.name..symbol
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
    local attrFH = attrF:getHeight()
    local descFH = descF:getHeight()

    local builder = ui.TooltipBuilder(mx, my, 0, 0, safeArea)

    -- Title
    builder:addText(getServerDataInputDisplayName(serverInfo), titleF, "center")

    -- Description
    if serverInfo.description then
        builder:addPadding(descFH / 4)
        builder:addText(serverInfo.description, descF, "center")
        builder:addPadding(descFH / 4)
    end

    -- Attributes
    builder:addText(getItemLoadText(serverInfo, serverData), attrF, "left")
    if serverData.powerNetwork then
        builder:addText(getPowerNetworkText(serverData.powerNetwork), attrF, "left")
    end

    -- CPS
    local actualCPS = serverData.computePerSecond
    local baseCPS = serverInfo.computePerSecond
    local cpsText = helper.wrapRichtextColor(g.COLORS.UI.TEXT_CPS, TEXT.CPS_NUMBER({cps = g.formatNumber(actualCPS)}))
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
    addLogMessages(serverData, builder)

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
    local descFH = descF:getHeight()

    local builder = ui.TooltipBuilder(mx, my, 0, 0, safeArea)

    -- Title
    builder:addText(dpInfo.name, titleF, "center")

    -- Description
    if dpInfo.description then
        builder:addPadding(descFH / 4)
        builder:addText(dpInfo.description, descF, "center")
        builder:addPadding(descFH / 4)
    end

    -- Attributes
    builder:addText(getItemLoadText(dpInfo, dpData), attrF, "left")
    if dpData.powerNetwork then
        builder:addText(getPowerNetworkText(dpData.powerNetwork), attrF, "left")
    end
    builder:addText(getDPS(dpInfo), attrF, "left")
        :addText(getWireDPS(dpInfo), attrF, "left")

    -- Log message
    addLogMessages(dpData, builder)

    builder:render()
end

---@param boosterData g.World.BoosterData
---@param mx number
---@param my number
---@param safeArea kirigami.Region
function ItemTooltip.BoosterTooltipWorld(boosterData, mx, my, safeArea)
    local boosterInfo = g.getItemInfo(boosterData.type, "booster")
    local titleF = ItemTooltip.getTitleFont()
    local attrF = ItemTooltip.getAttrFont()
    local descF = ItemTooltip.getDescFont()
    local descFH = descF:getHeight()

    local builder = ui.TooltipBuilder(mx, my, 0, 0, safeArea)

    -- Title
    builder:addText(boosterInfo.name, titleF, "center")

    -- Description
    if boosterInfo.description then
        builder:addPadding(descFH / 4)
        builder:addText(boosterInfo.description, descF, "center")
        builder:addPadding(descFH / 4)
    end

    -- Attributes
    builder:addText(getItemLoadText(boosterInfo, boosterData), attrF, "left")
    if boosterData.powerNetwork then
        builder:addText(getPowerNetworkText(boosterData.powerNetwork), attrF, "left")
    end
    -- Connections
    if boosterInfo.connectable then
        local conn = TEXT.WIRE_COUNT({count = #boosterData.connectsTo, max = boosterInfo.connectable.max})
        if #boosterData.connectsTo > boosterInfo.connectable.max then
            conn = helper.wrapRichtextColor(g.COLORS.UI.WARNING, conn)
        end
        builder:addText(conn, attrF, "left")
    end
    -- Effectivity
    local effectivity = TEXT.EFFECTIVITY({effectivity = helper.round(boosterData.effectiveness * 100, 2)})
    if boosterData.effectiveness < 0.75 then
        effectivity = helper.wrapRichtextColor(g.COLORS.UI.DEBUFF, effectivity)
    elseif boosterData.effectiveness < 1 then
        effectivity = helper.wrapRichtextColor(g.COLORS.UI.WARNING, effectivity)
    end
    builder:addText(effectivity, attrF, "left")

    -- Log message
    addLogMessages(boosterData, builder)

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
    local descFH = descF:getHeight()

    local builder = ui.TooltipBuilder(mx, my, 0, 0, safeArea)

    -- Title
    builder:addText(getServerDataInputDisplayName(diInfo), titleF, "center")

    -- Description
    if diInfo.description then
        builder:addPadding(descFH / 4)
        builder:addText(diInfo.description, descF, "center")
        builder:addPadding(descFH / 4)
    end

    -- Buffs
    if diInfo.jobFrequencyModifier > 0 then
        local t = TEXT.JOB_FREQUENCY_MODIFIER({
            modifier = g.formatNumber(diInfo.jobFrequencyModifier),
            jobtype = g.getJobCategoryInfo(diInfo.queuesJob).name
        })
        builder:addText(helper.wrapRichtextColor(g.COLORS.UI.BUFF, t), attrF, "left")
    end
    if diInfo.jobFrequencyMultiplier > 1 then
        local t = TEXT.JOB_FREQUENCY_MULTIPLIER({
            multiplier = helper.round(diInfo.jobFrequencyMultiplier * 100, 2),
            jobtype = g.getJobCategoryInfo(diInfo.queuesJob).name
        })
        builder:addText(helper.wrapRichtextColor(g.COLORS.UI.BUFF, t), attrF, "left")
    end

    -- Attributes
    builder:addText(getItemLoadText(diInfo, diData), attrF, "left")
    if diData.powerNetwork then
        builder:addText(getPowerNetworkText(diData.powerNetwork), attrF, "left")
    end
    -- builder:addText(TEXT.CATEGORY_LIST({
    --     categories = g.getJobCategoryInfo(diInfo.queuesJob).name
    -- }), attrF, "left")

    -- Log message
    addLogMessages(diData, builder)

    builder:render()
end

---@param powerData g.World.PowerData
---@param mx number
---@param my number
---@param safeArea kirigami.Region
function ItemTooltip.DrawPowerGenTooltip(powerData, mx, my, safeArea)
    local powerGenInfo = g.getItemInfo(powerData.type, "powergen")
    local titleF = ItemTooltip.getTitleFont()
    local attrF = ItemTooltip.getAttrFont()
    local descF = ItemTooltip.getDescFont()
    local descFH = descF:getHeight()

    local builder = ui.TooltipBuilder(mx, my, 0, 0, safeArea)

    -- Title
    builder:addText(powerGenInfo.name, titleF, "center")

    -- Description
    if powerGenInfo.description then
        builder:addPadding(descFH / 4)
        builder:addText(powerGenInfo.description, descF, "center")
        builder:addPadding(descFH / 4)
    end

    -- Attributes
    builder:addText(getGeneratorOutput(powerGenInfo), attrF, "left")
    if powerData.powerNetwork then
        builder:addText(getPowerNetworkText(powerData.powerNetwork), attrF, "left")
    end

    -- Log message
    addLogMessages(powerData, builder)

    builder:render()
end


---@param powerData g.World.PowerData
---@param mx number
---@param my number
---@param safeArea kirigami.Region
function ItemTooltip.DrawPowerRelayTooltip(powerData, mx, my, safeArea)
    local powerRelayInfo = g.getItemInfo(powerData.type, "powerrelay")
    local titleF = ItemTooltip.getTitleFont()
    local attrF = ItemTooltip.getAttrFont()
    local descF = ItemTooltip.getDescFont()
    local descFH = descF:getHeight()

    local builder = ui.TooltipBuilder(mx, my, 0, 0, safeArea)

    -- Title
    builder:addText(powerRelayInfo.name, titleF, "center")

    -- Description
    if powerRelayInfo.description then
        builder:addPadding(descFH / 4)
        builder:addText(powerRelayInfo.description, descF, "center")
        builder:addPadding(descFH / 4)
    end

    -- Attributes
    if powerData.powerNetwork then
        builder:addText(getPowerNetworkText(powerData.powerNetwork), attrF, "left")
    end

    -- Log message
    addLogMessages(powerData, builder)

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
        ---@cast itemData g.World.BoosterData
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
---@param safeArea kirigami.Region?
function ItemTooltip.ServerTooltipHUD(serverInfo, x, y, safeArea)
    local titleF = ItemTooltip.getTitleFont()
    local attrF = ItemTooltip.getAttrFont()
    local descF = ItemTooltip.getDescFont()
    local descFH = descF:getHeight()

    local builder = ui.TooltipBuilder(x, y, 0.5, 1, safeArea)

    -- Title
    builder:addText(getServerDataInputDisplayName(serverInfo), titleF, "center")

    -- Description
    if serverInfo.description then
        builder:addPadding(descFH / 4)
        builder:addText(serverInfo.description, descF, "center")
        builder:addPadding(descFH / 4)
    end

    -- Attributes
    -- Price
    local priceText = getItemPrice(serverInfo)
    if priceText then
        builder:addText(priceText, attrF, "left")
    end
    -- Load
    builder:addText(getItemLoadText(serverInfo), attrF, "left")
    -- CPS
    builder:addText(
        helper.wrapRichtextColor(g.COLORS.UI.TEXT_CPS, TEXT.CPS_NUMBER({cps = g.formatNumber(serverInfo.computePerSecond)})),
        attrF, "left"
    )
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
---@param safeArea kirigami.Region?
function ItemTooltip.DPTooltipHUD(dpInfo, x, y, safeArea)
    local titleF = ItemTooltip.getTitleFont()
    local attrF = ItemTooltip.getAttrFont()
    local descF = ItemTooltip.getDescFont()
    local descFH = descF:getHeight()

    local builder = ui.TooltipBuilder(x, y, 0.5, 1, safeArea)

    -- Title
    builder:addText(dpInfo.name, titleF, "center")

    -- Description
    if dpInfo.description then
        builder:addPadding(descFH / 4)
        builder:addText(dpInfo.description, descF, "center")
        builder:addPadding(descFH / 4)
    end

    -- Attributes
    -- Price
    local priceText = getItemPrice(dpInfo)
    if priceText then
        builder:addText(priceText, attrF, "left")
    end
    -- Load
    builder:addText(getItemLoadText(dpInfo), attrF, "left")
    -- DPS
    builder:addText(getDPS(dpInfo), attrF, "left")
    -- Wire DPS
    builder:addText(getWireDPS(dpInfo), attrF, "left")

    builder:render()
end

---@param diInfo g.DataInInfo
---@param x number relative to bottom center
---@param y number relative to bottom center
---@param safeArea kirigami.Region?
function ItemTooltip.DITooltipHUD(diInfo, x, y, safeArea)
    local titleF = ItemTooltip.getTitleFont()
    local attrF = ItemTooltip.getAttrFont()
    local descF = ItemTooltip.getDescFont()
    local descFH = descF:getHeight()

    local builder = ui.TooltipBuilder(x, y, 0.5, 1, safeArea)

    -- Title
    builder:addText(getServerDataInputDisplayName(diInfo), titleF, "center")

    -- Description
    if diInfo.description then
        builder:addPadding(descFH / 4)
        builder:addText(diInfo.description, descF, "center")
        builder:addPadding(descFH / 4)
    end

    -- Buffs
    if diInfo.jobFrequencyModifier > 0 then
        local t = TEXT.JOB_FREQUENCY_MODIFIER({
            modifier = g.formatNumber(diInfo.jobFrequencyModifier),
            jobtype = g.getJobCategoryInfo(diInfo.queuesJob).name
        })
        builder:addText(helper.wrapRichtextColor(g.COLORS.UI.BUFF, t), attrF, "left")
    end
    if diInfo.jobFrequencyMultiplier > 1 then
        local t = TEXT.JOB_FREQUENCY_MULTIPLIER({
            modifier = helper.round(diInfo.jobFrequencyMultiplier * 100, 2),
            jobtype = g.getJobCategoryInfo(diInfo.queuesJob).name
        })
        builder:addText(helper.wrapRichtextColor(g.COLORS.UI.BUFF, t), attrF, "left")
    end

    -- Attributes
    -- Price
    local priceText = getItemPrice(diInfo)
    if priceText then
        builder:addText(priceText, attrF, "left")
    end
    -- Load
    builder:addText(getItemLoadText(diInfo), attrF, "left")
    -- Queued Job Category
    -- builder:addText(TEXT.CATEGORY_LIST({
    --     categories = g.getJobCategoryInfo(diInfo.queuesJob).name
    -- }), attrF, "left")

    builder:render()
end

---@param boosterInfo g.BoosterInfo
---@param x number
---@param y number
---@param safeArea kirigami.Region?
function ItemTooltip.BoosterTooltipHUD(boosterInfo, x, y, safeArea)
    local titleF = ItemTooltip.getTitleFont()
    local attrF = ItemTooltip.getAttrFont()
    local descF = ItemTooltip.getDescFont()
    local descFH = descF:getHeight()

    local builder = ui.TooltipBuilder(x, y, 0.5, 1, safeArea)

    -- Title
    builder:addText(boosterInfo.name, titleF, "center")

    -- Description
    if boosterInfo.description then
        builder:addPadding(descFH / 4)
        builder:addText(boosterInfo.description, descF, "center")
        builder:addPadding(descFH / 4)
    end

    -- Attributes
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
---@param safeArea kirigami.Region?
function ItemTooltip.PowerGenTooltipHUD(powerGenInfo, x, y, safeArea)
    local titleF = ItemTooltip.getTitleFont()
    local attrF = ItemTooltip.getAttrFont()
    local descF = ItemTooltip.getDescFont()
    local descFH = descF:getHeight()

    local builder = ui.TooltipBuilder(x, y, 0.5, 1, safeArea)

    -- Title
    builder:addText(powerGenInfo.name, titleF, "center")

    -- Description
    if powerGenInfo.description then
        builder:addPadding(descFH / 4)
        builder:addText(powerGenInfo.description, descF, "center")
        builder:addPadding(descFH / 4)
    end

    -- Attributes
    -- Price
    local priceText = getItemPrice(powerGenInfo)
    if priceText then
        builder:addText(priceText, attrF, "left")
    end
    -- Load
    builder:addText(getGeneratorOutput(powerGenInfo), attrF, "left")

    builder:render()
end

---@param powerRelayInfo g.PowerRelayInfo
---@param x number
---@param y number
---@param safeArea kirigami.Region?
function ItemTooltip.PowerRelayTooltipHUD(powerRelayInfo, x, y, safeArea)
    local titleF = ItemTooltip.getTitleFont()
    local attrF = ItemTooltip.getAttrFont()
    local descF = ItemTooltip.getDescFont()
    local descFH = descF:getHeight()

    local builder = ui.TooltipBuilder(x, y, 0.5, 1, safeArea)

    -- Title
    builder:addText(powerRelayInfo.name, titleF, "center")

    -- Description
    if powerRelayInfo.description then
        builder:addPadding(descFH / 4)
        builder:addText(powerRelayInfo.description, descF, "center")
        builder:addPadding(descFH / 4)
    end

    -- Attributes
    -- Price
    local priceText = getItemPrice(powerRelayInfo)
    if priceText then
        builder:addText(priceText, attrF, "left")
    end

    builder:render()
end

---@param itemInfo g.ItemInfo<g.World.ItemData>
---@param x number
---@param y number
---@param safeArea kirigami.Region?
function ItemTooltip.DrawHUDTooltip(itemInfo, x, y, safeArea)
    local col = gsman.setColor(1, 1, 1)
    if itemInfo.category == "server" then
        ---@cast itemInfo g.ServerInfo
        ItemTooltip.ServerTooltipHUD(itemInfo, x, y, safeArea)
    elseif itemInfo.category == "data" then
        ---@cast itemInfo g.DataOutInfo
        ItemTooltip.DPTooltipHUD(itemInfo, x, y, safeArea)
    elseif itemInfo.category == "indata" then
        ---@cast itemInfo g.DataInInfo
        ItemTooltip.DITooltipHUD(itemInfo, x, y, safeArea)
    elseif itemInfo.category == "booster" then
        ---@cast itemInfo g.BoosterInfo
        ItemTooltip.BoosterTooltipHUD(itemInfo, x, y, safeArea)
    elseif itemInfo.category == "powergen" then
        ---@cast itemInfo g.PowerGenInfo
        ItemTooltip.PowerGenTooltipHUD(itemInfo, x, y, safeArea)
    elseif itemInfo.category == "powerrelay" then
        ---@cast itemInfo g.PowerRelayInfo
        ItemTooltip.PowerRelayTooltipHUD(itemInfo, x, y, safeArea)
    else
        error("unreachable category")
    end
    col:pop()
end

return ItemTooltip
