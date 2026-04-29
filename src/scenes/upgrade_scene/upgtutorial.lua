---@param safeArea kirigami.Region
local function renderTutorial6(safeArea)
    local ack = false
    local textF = g.getMainFont(12)

    local builder = ui.TooltipBuilder(safeArea.x + safeArea.w, safeArea.y + safeArea.h, 1, 1, safeArea, 180)
    builder:addText(TEXT.TUTORIAL_6_1, textF, "center")
    builder:addText(TEXT.TUTORIAL_6_2, textF, "center")

    builder:addPadding(4)
    builder:addCustom(32, function(x, y, w, h)
        local r = Kirigami(x, y, w, h):padRatio(0.25, 0.25, 0.25, 0.25)
        if ui.Button2(TEXT.TUTORIAL_NEXT, textF, objects.Color.BLACK, r) then
            ack = true
        end
    end)
    builder:addPadding(4)

    builder:render()

    return ack
end

---@param safeArea kirigami.Region
local function renderTutorial7(safeArea)
    local skipped = false
    local textF = g.getMainFont(12)
    local bs = g.getItemInfo("basic_server", "server")
    local bdi = g.getItemInfo("basic_indata", "indata")
    local bdo = g.getItemInfo("basic_data", "data")

    local builder = ui.TooltipBuilder(safeArea.x + safeArea.w, safeArea.y + safeArea.h, 1, 1, safeArea, 180)
    builder:addText(TEXT.TUTORIAL_7_1, textF, "center")
    builder:addText(TEXT.TUTORIAL_7_2({bs = bs.name, di = bdi.name, ["do"] = bdo.name}), textF, "center")

    builder:addPadding(4)
    builder:addCustom(32, function(x, y, w, h)
        local r = Kirigami(x, y, w, h):padRatio(0.25, 0.25, 0.25, 0.25)
        if ui.Button2(TEXT.TUTORIAL_SKIP, textF, objects.Color.BLACK, r) then
            skipped = true
        end
    end)
    builder:addPadding(4)

    builder:render()

    return skipped
end

return {
    [6] = renderTutorial6,
    [7] = renderTutorial7,
}
