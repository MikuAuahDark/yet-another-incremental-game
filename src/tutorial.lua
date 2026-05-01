
---@param safeArea kirigami.Region
local function renderTutorial0(safeArea)
    local mode = 0
    local textF = g.getMainFont(12)
    local mainpower = g.getItemInfo("main_power", "powergen")

    local builder = ui.TooltipBuilder(safeArea.x + safeArea.w, safeArea.y + safeArea.h, 1, 1, safeArea, 200)
    builder:addText(TEXT.TUTORIAL_0_1, textF, "center")
    builder:addText(TEXT.TUTORIAL_0_2, textF, "center")
    builder:addText(TEXT.TUTORIAL_0_3, textF, "center")
    builder:addText(TEXT.TUTORIAL_0_4({main_power = mainpower.name}), textF, "center")

    builder:addPadding(4)
    builder:addCustom(32, function(x, y, w, h)
        local r = Kirigami(x, y, w, h):padRatio(0.25, 0.25, 0.25, 0.25)
        if ui.Button2(TEXT.TUTORIAL_SKIP_ALL, textF, objects.Color.BLACK, r) then
            mode = 1
        end
    end)
    builder:addPadding(4)
    builder:addCustom(32, function(x, y, w, h)
        local r = Kirigami(x, y, w, h):padRatio(0.25, 0.25, 0.25, 0.25)
        if ui.Button2(TEXT.TUTORIAL_NEXT, textF, objects.Color.BLACK, r) then
            mode = 2
        end
    end)
    builder:addPadding(4)

    builder:render()

    return mode
end

---@param safeArea kirigami.Region
local function renderTutorial1(safeArea)
    local skipped = false
    local textF = g.getMainFont(12)
    local bs = g.getItemInfo("basic_server", "server")

    local builder = ui.TooltipBuilder(safeArea.x + safeArea.w, safeArea.y + safeArea.h, 1, 1, safeArea, 150)
    builder:addText(TEXT.TUTORIAL_1_1, textF, "center")
    builder:addText(TEXT.TUTORIAL_1_2({server = bs.name}), textF, "center")

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

---@param safeArea kirigami.Region
local function renderTutorial2(safeArea)
    local skipped = false
    local textF = g.getMainFont(12)
    local bdi = g.getItemInfo("basic_indata", "indata")

    local builder = ui.TooltipBuilder(safeArea.x + safeArea.w, safeArea.y + safeArea.h, 1, 1, safeArea, 180)
    builder:addText(TEXT.TUTORIAL_2_1, textF, "center")
    builder:addText(TEXT.TUTORIAL_2_2(TEXT), textF, "center")
    builder:addText(TEXT.TUTORIAL_2_3({di = bdi.name}), textF, "center")

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

---@param safeArea kirigami.Region
local function renderTutorial3(safeArea)
    local skipped = false
    local textF = g.getMainFont(12)
    local bdo = g.getItemInfo("basic_data", "data")

    local builder = ui.TooltipBuilder(safeArea.x + safeArea.w, safeArea.y + safeArea.h, 1, 1, safeArea, 150)
    builder:addText(TEXT.TUTORIAL_3_1, textF, "center")
    builder:addText(TEXT.TUTORIAL_3_2({["do"] = bdo.name}), textF, "center")

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

---@param safeArea kirigami.Region
local function renderTutorial4(safeArea)
    local ack = false
    local textF = g.getMainFont(12)

    local builder = ui.TooltipBuilder(safeArea.x + safeArea.w, safeArea.y + safeArea.h, 1, 1, safeArea, 180)
    builder:addText(TEXT.TUTORIAL_4_1, textF, "center")
    builder:addText(TEXT.TUTORIAL_4_2, textF, "center")

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

local function renderTutorial5(safeArea)
    local ack = false
    local textF = g.getMainFont(12)

    local builder = ui.TooltipBuilder(safeArea.x + safeArea.w, safeArea.y + safeArea.h, 1, 1, safeArea, 180)
    builder:addText(TEXT.TUTORIAL_5_1, textF, "center")
    builder:addText(TEXT.TUTORIAL_5_2, textF, "center")

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
    -- builder:addText(TEXT.TUTORIAL_7_1, textF, "center") -- this is just repeating same thing as 6_1, I dont think we need?
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

local function renderTutorial8(safeArea)
    local ack = false
    local textF = g.getMainFont(12)

    local builder = ui.TooltipBuilder(safeArea.x + safeArea.w, safeArea.y + safeArea.h, 1, 1, safeArea, 180)
    builder:addText(TEXT.TUTORIAL_8_1, textF, "center")
    builder:addText(TEXT.TUTORIAL_8_2, textF, "center")

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

local function renderTutorial9(safeArea)
    local ack = false
    local textF = g.getMainFont(12)

    local builder = ui.TooltipBuilder(safeArea.x + safeArea.w, safeArea.y + safeArea.h, 1, 1, safeArea, 180)
    builder:addText(TEXT.TUTORIAL_9_1, textF, "center")
    builder:addText(TEXT.TUTORIAL_9_2, textF, "left")
    builder:addText(TEXT.TUTORIAL_9_3, textF, "left")
    builder:addText(TEXT.TUTORIAL_9_4, textF, "left")

    builder:addPadding(4)
    builder:addCustom(32, function(x, y, w, h)
        local r = Kirigami(x, y, w, h):padRatio(0.25, 0.25, 0.25, 0.25)
        if ui.Button2(TEXT.TUTORIAL_FINISH, textF, objects.Color.BLACK, r) then
            ack = true
        end
    end)
    builder:addPadding(4)

    builder:render()

    return ack
end

return {
    [0] = renderTutorial0,
    [1] = renderTutorial1,
    [2] = renderTutorial2,
    [3] = renderTutorial3,
    [4] = renderTutorial4,
    [5] = renderTutorial5,
    [6] = renderTutorial6,
    [7] = renderTutorial7,
    [8] = renderTutorial8,
    [9] = renderTutorial9,
}
