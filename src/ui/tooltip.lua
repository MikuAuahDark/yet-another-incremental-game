---@class ui.ItemTooltip
local ItemTooltip = {}


---@param itemInfo g.MachineInfo
---@param itemData g.World.MachineData?
local function getItemLoadText(itemInfo, itemData)
    local baseLoad = itemInfo.powerLoad or 0
    local actualLoad = baseLoad
    if itemData then
        actualLoad = itemData.powerLoad
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


---@param machine g.World.MachineData
---@param builder ui.TooltipBuilder
local function addLogMessages(machine, builder)
    local problems = g.getMachineProblems(machine)
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


-- Putting this here so font sizes can be changed in one place
function ItemTooltip.getTitleFont() return g.getMainFont(16) end
function ItemTooltip.getAttrFont() return g.getMainFont(13) end
function ItemTooltip.getDescFont() return g.getMainFont(10) end


---@param machine g.World.MachineData
---@param mx number relative to bottom center
---@param my number relative to bottom center
---@param safeArea kirigami.Region
function ItemTooltip.DrawWorldTooltip(machine, mx, my, safeArea)
    local col = gsman.setColor(1, 1, 1)

    local minfo = g.getMachineInfo(machine.type)
    local titleF = ItemTooltip.getTitleFont()
    local attrF = ItemTooltip.getAttrFont()
    local descF = ItemTooltip.getDescFont()
    local attrFH = attrF:getHeight()
    local descFH = descF:getHeight()

    local builder = ui.TooltipBuilder(mx, my, 0, 0, safeArea)

    -- Title
    builder:addText(minfo.name, titleF, "center")

    -- Description
    if minfo.description then
        builder:addPadding(descFH / 4)
        builder:addText(minfo.description, descF, "center")
        builder:addPadding(descFH / 4)
    end

    -- Requires
    local showRequires = (machine.powerLoad and machine.powerLoad > 0) or #machine.input > 0
    if showRequires then
        builder:addText(TEXT.REQUIRES, attrF, "left")

        if machine.powerLoad and machine.powerLoad > 0 then
            local powerText = getItemLoadText(minfo, machine)
            builder:addText("  "..powerText, attrF, "left")
        end

        for _, iset in ipairs(machine.input) do
            local itext = TEXT.DATA_REQUIREMENT_WORLD({
                amount = #iset.queue,
                required = iset.amount,
                data = g.getRichtextForShapeAndColor(iset.shapes, iset.colors)
            })
            builder:addText("  "..itext, attrF, "left")
        end
    end

    -- Provides
    local showProvides = (machine.powerGenerate or 0) > 0 or (machine.output and machine.processTime and machine.processTime > 0)
    if showProvides then
        builder:addText(TEXT.PROVIDES, attrF, "left")
        if machine.powerGenerate and machine.powerGenerate > 0 then
            local powerText = TEXT.LOAD_TOOLTIP({
                load = machine.powerGenerate
            })
            builder:addText("  "..powerText, attrF, "left")
        end

        if machine.output then
            local outText = TEXT.DATA_PROVIDE({
                value = machine.output.amount / machine.processTime,
                data = g.getRichtextForShapeAndColor(machine.output.shapes, machine.output.colors)
            })
            builder:addText("  "..outText, attrF, "left")
        end
    end

    -- Power Network
    if machine.powerNetwork then
        builder:addText(getPowerNetworkText(machine.powerNetwork), attrF, "left")
    end

    -- Heat
    if minfo.heatTolerance then
        local heat = g.getTileHeat(machine.tileX, machine.tileY)
        local heatText = TEXT.SERVER_HEAT_NUMBER({
            heat = g.formatNumber(heat),
            max_heat = g.formatNumber(minfo.heatTolerance[2])
        })
        if heat > minfo.heatTolerance[2] then
            heatText = helper.wrapRichtextColor(g.COLORS.UI.DEBUFF, heatText .. " {emergency_heat}")
        elseif heat < minfo.heatTolerance[1] then
            heatText = helper.wrapRichtextColor(g.COLORS.UI.OVERCLOCKED, heatText .. " {snowflake}")
        end
        builder:addText(heatText, attrF, "left")
    end

    -- Log message
    addLogMessages(machine, builder)

    builder:render()
    col:pop()
end


---@param minfo g.MachineInfo
---@param builder ui.TooltipBuilder
function ItemTooltip.ProvideCommonTooltipHUD(minfo, builder)
    local attrF = ItemTooltip.getAttrFont()
    local descF = ItemTooltip.getDescFont()
    local descFH = descF:getHeight()

    -- Description
    if minfo.description then
        builder:addPadding(descFH / 4)
        builder:addText(minfo.description, descF, "center")
        builder:addPadding(descFH / 4)
    end

    -- Requires
    local showRequires = (minfo.powerLoad and minfo.powerLoad > 0) or #minfo.input > 0
    if showRequires then
        builder:addText(TEXT.REQUIRES, attrF, "left")

        if minfo.powerLoad and minfo.powerLoad > 0 then
            local powerText = getItemLoadText(minfo)
            builder:addText("  "..powerText, attrF, "left")
        end

        for _, iset in ipairs(minfo.input) do
            local itext = TEXT.DATA_REQUIREMENT_HUD({
                required = iset.amount,
                data = g.getRichtextForShapeAndColor(iset.shapes, iset.colors)
            })
            builder:addText("  "..itext, attrF, "left")
        end
    end

    -- Provides
    local showProvides = (minfo.powerGenerate or 0) > 0 or (minfo.output and minfo.processTime and minfo.processTime > 0)
    if showProvides then
        builder:addText(TEXT.PROVIDES, attrF, "left")
        if minfo.powerGenerate and minfo.powerGenerate > 0 then
            local powerText = TEXT.LOAD_TOOLTIP({
                load = minfo.powerGenerate
            })
            builder:addText("  "..powerText, attrF, "left")
        end

        if minfo.output then
            local outText = TEXT.DATA_PROVIDE({
                value = minfo.output.amount / minfo.processTime,
                data = g.getRichtextForShapeAndColor(minfo.output.shapes, minfo.output.colors)
            })
            builder:addText("  "..outText, attrF, "left")
        end
    end

    -- Heat tolerance
    if minfo.heatTolerance then
        builder:addText(TEXT.HEAT_TOLERANCE({
            min_heat = g.formatNumber(minfo.heatTolerance[1]),
            max_heat = g.formatNumber(minfo.heatTolerance[2])
        }), attrF, "left")
    end
end

---@param minfo g.MachineInfo
---@param x number
---@param y number
---@param safeArea kirigami.Region?
function ItemTooltip.DrawHUDTooltip(minfo, x, y, safeArea)
    local col = gsman.setColor(1, 1, 1)
    local titleF = ItemTooltip.getTitleFont()

    local builder = ui.TooltipBuilder(x, y, 0.5, 1, safeArea)

    -- Title
    builder:addText(minfo.name, titleF, "center")

    ItemTooltip.ProvideCommonTooltipHUD(minfo, builder)

    builder:render()
    col:pop()
end

return ItemTooltip
