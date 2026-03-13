local objects = require("src.modules.objects.objects")


---Doesn't have to be perfect. Just for visualization purposes.
---@type table<g.Job, number?>
local jobTimeoutLookup = setmetatable({}, {__mode = "k"})

---@param job g.Job
local function getJobTimeout(job)
    local tmt = jobTimeoutLookup[job]
    if not tmt then
        tmt = job.timeout
        jobTimeoutLookup[job] = tmt
    end

    return tmt
end

---@param job g.Job
---@param r kirigami.Region full area (without padding)
---@param theme "dark"|"light"
local function drawJobCard(job, r, theme)
    local baseR = r:padUnit(4, 4, 8, 4)
    local titleF = g.getMainFont(16)
    local catF = g.getMainFont(10)

    local titleR, catR, outR = helper.splitRegionByExactSizes(
        baseR, "vertical",
        titleF:getHeight(),
        catF:getHeight(),
        titleF:getHeight(),
        0
    )
    love.graphics.setColor(g.COLORS.UI.MAIN[theme].CARD)
    love.graphics.rectangle("fill", r:get())
    love.graphics.setColor(g.COLORS.UI.MAIN[theme].TEXT)
    local lw = gsman.setLineWidth(1)
    love.graphics.rectangle("line", r:get())
    lw:pop()

    -- Draw text
    love.graphics.setColor(g.COLORS.UI.MAIN[theme].TEXT)
    richtext.printRichContainedNoWrap(job.name, titleF, titleR:get())
    ui.printRichInRegion(g.getJobCategoryName(job.category), catF, catR, true, "left")
    local computeR, dataR, moneyR = outR:splitHorizontal(1, 1, 1)
    ui.printRichInRegion(g.formatNumber(job.computePower).."{dns}", catF, computeR, true, "left")
    ui.printRichInRegion(g.formatNumber(job.outputData).."{database}", catF, dataR, true, "center")
    -- We only have "money"
    -- FIXME: Change it if we have more than 1 resources
    ui.printRichInRegion("{money}"..g.formatNumber(job.resource.money), catF, moneyR, true, "right")

    -- Draw timeout bar
    local timeoutWidth = helper.clamp(job.timeout * r.w / math.max(getJobTimeout(job), 1), 0, r.w)
    love.graphics.rectangle("fill", r.x, r.y + r.h - 4, timeoutWidth, 4)
end

local function getJobCardHeight()
    local titleF = g.getMainFont(16)
    local catF = g.getMainFont(10)
    return 4 + titleF:getHeight() + catF:getHeight() * 2 + 4
end

---@param r kirigami.Region
---@param count integer
---@param itemListSize number
---@param horzPadding number
local function generateItemListRegion(r, count, itemListSize, horzPadding)
    local totalWidth = count * itemListSize + math.max(count - 1, 0) * horzPadding
    ---@type kirigami.Region[]
    local result = {}
    local ox = 0
    for _ = 1, count do
        result[#result+1] = Kirigami(r.x + ox, r.y, itemListSize, r.h)
        ox = ox + itemListSize + horzPadding
    end
    return result, totalWidth
end


local MAX_TOOLTIP_WIDTH = 180

---@param x number
---@param y number
---@param title string
---@param description string
local function drawTooltipWithDescription(x, y, title, description)
    local titleF = g.getMainFont(16)
    local descF = g.getMainFont(12)
    local titleFH = titleF:getHeight()
    local descFH = descF:getHeight()

    -- Compute sizes
    local width, height = 0, 0
    -- Title
    local titleHeight
    do
        local w, l = richtext.getWrap(title, titleF, MAX_TOOLTIP_WIDTH)
        width = helper.clamp(width, w, MAX_TOOLTIP_WIDTH)
        titleHeight = l * titleFH
        height = height + titleHeight
    end
    -- Description
    local descriptionHeight = 0
    do
        local w, l = richtext.getWrap(description, descF, MAX_TOOLTIP_WIDTH)
        width = helper.clamp(width, w, MAX_TOOLTIP_WIDTH)
        descriptionHeight = l * descFH
        height = height + descriptionHeight
    end

    -- Generate region now
    local tdrawableR, tcntR = ui.getTooltipRegion(x - width / 2, y, width, height, ui.getFullScreenRegion())
    ui.Tooltip(tdrawableR, objects.Color.BLACK, objects.Color.WHITE)

    -- Pass 2: Draw the tooltip
    height = 0
    do
        richtext.printRich(title, titleF, tcntR.x, tcntR.y + height, tcntR.w, "center")
        height = height + titleHeight
    end
    -- Draw description
    do
        richtext.printRich(description, descF, tcntR.x, tcntR.y + height, tcntR.w, "center")
        height = height + descriptionHeight
    end
end

---@param b boolean?
local function nilIsTrue(b)
    if b == nil then return true end
    return not not b
end


---@class g.HUD: objects.Class
---@field freeArea kirigami.Region
local HUD = objects.Class("g:HUD")

function HUD:init()
    -- Used for stats
    self.topR = Kirigami(0, 0, 1, 1)
    -- Used for job queues
    self.leftR = Kirigami(0, 0, 1, 1)
    -- Used for building list
    self.botR = Kirigami(0, 0, 1, 1)
    ---@type g.ItemCategory
    self.activeTab = "server"
    ---@type [number,g.ItemInfo]? when dragging from item list to world. [1] = duration, [2] = item info
    self.activeDragging = nil
    ---@type [number,number,g.ItemInfo]? for tooltip pinning
    self.selectedItem = nil
end

if false then
    ---@return g.HUD
    ---@diagnostic disable-next-line: cast-local-type, missing-return
    function HUD() end
end

---@param dt number
function HUD:update(dt)
    local r = ui.getScreenRegion()
    self.topR = r:set(nil, nil, nil, 28)
    self.leftR = r:set(nil, nil, 150):padUnit(0, self.topR.h, 0, 0)
    self.botR = r:padUnit(self.leftR.w, 0, 0, 0)
        :set(nil, nil, nil, 112)
        :attachToBottomOf(r)
        :moveRatio(0, -1)

    if self.activeDragging then
        self.activeDragging[1] = self.activeDragging[1] + dt
    end
end

---@param r kirigami.Region
---@param theme "dark"|"light"
local function drawPanelWithBorder(r, theme)
    love.graphics.setColor(g.COLORS.UI.MAIN[theme].PANEL)
    love.graphics.rectangle("fill", r:get())
    love.graphics.setColor(g.COLORS.UI.BORDER)
    love.graphics.rectangle("line", r:get())
end

---@param r kirigami.Region
---@param title string
---@param desc string
---@param left string
---@param right string
---@param col objects.Color?
local function drawStats(r, title, desc, left, right, col)
    local font = g.getMainFont(18)
    local padR = r:padUnit(4)

    local col1 = gsman.setColor(0, 0, 0)
    local radius = math.min(padR.w, padR.h) / 2
    helper.quickRoundedRectangle("fill", radius, padR)
    helper.quickRoundedRectangle("line", radius, padR)
    col1:pop()

    local oy = padR.y + (padR.h - font:getHeight()) / 2
    local col2 = gsman.setColor(col or objects.Color.WHITE)
    richtext.printRich(left, font, padR.x + 8, oy, padR.w, "left")
    richtext.printRich(right, font, padR.x - 8, oy, padR.w, "right")
    col2:pop()

    if iml.isHovered(padR:get()) then
        local col3 = gsman.setColor(1, 1, 1)
        drawTooltipWithDescription(padR.x + padR.w / 2, padR.y + padR.h + 8, title, desc)
        col3:pop()
    end
end

---@param show {stats:boolean?,jobQueue:boolean?,itemList:boolean?}?
function HUD:draw(show)
    prof_push("HUD:draw")

    local showStats = nilIsTrue(show and show.stats)
    local showJobQueue = nilIsTrue(show and show.jobQueue)
    local showItemList = nilIsTrue(show and show.itemList)

    local lineWidth = gsman.setLineWidth(2)
    local theme = g.getSystemTheme()
    local tabF = g.getMainFont(16)
    if showStats then
        drawPanelWithBorder(self.topR, theme)
    end
    if showJobQueue then
        drawPanelWithBorder(self.leftR, theme)
    end
    if showItemList then
        drawPanelWithBorder(self.botR:padUnit(0, tabF:getHeight(), 0, 0), theme)
    end

    if g.hasSession() then
        local world = g.getMainWorld()

        -- Draw job queue
        if showJobQueue then
            local jobQueueF = g.getMainFont(10)
            -- TODO: Add scrollbars
            local jobTextR, jobQR = helper.splitRegionByExactSizes(
                self.leftR:padUnit(4, 4, 4, 0),
                "vertical",
                jobQueueF:getHeight(),
                0
            )

            -- Draw job queue text
            local jobQueueText = TEXT.JOB_QUEUE_NUMBER({
                njobs = #world.jobQueue,
                maxjobs = helper.round(g.stats.MaxJobQueue),
            })
            love.graphics.setColor(g.COLORS.UI.MAIN[theme].TEXT)
            ui.printRichInRegion(jobQueueText, jobQueueF, jobTextR)

            local jobCardHeight = getJobCardHeight()
            local iterCount = math.min(#world.jobQueue, math.floor(jobQR.h / (jobCardHeight + 4)))

            for i = 1, iterCount do
                local jq = world.jobQueue[i]
                local y = jobQR.y + (i - 1) * (jobCardHeight + 4)
                local jobCardR = Kirigami(jobQR.x, y, jobQR.w, jobCardHeight)
                drawJobCard(jq, jobCardR, theme)
            end
        end

        if showItemList then
            -- Draw item list
            local TRAPEZOID_PADDING = 10
            local tabR, listR, scrollR = helper.splitRegionByExactSizes(self.botR:padUnit(1), "vertical", tabF:getHeight(), 0, 10)
            local serversTabR, dataTabR, boostersTabR = helper.splitRegionByExactSizes(
                tabR, "horizontal",
                tabF:getWidth(TEXT.CATEGORY_SERVER) + 2 * (TRAPEZOID_PADDING + 1),
                tabF:getWidth(TEXT.CATEGORY_DATA) + 2 * (TRAPEZOID_PADDING + 1),
                tabF:getWidth(TEXT.CATEGORY_BOOSTER) + 2 * (TRAPEZOID_PADDING + 1),
                0
            )
            ---@type table<g.ItemCategory, [kirigami.Region, string]>
            local tabs = {
                server = {serversTabR, TEXT.CATEGORY_SERVER},
                data = {dataTabR, TEXT.CATEGORY_DATA},
                booster = {boostersTabR, TEXT.CATEGORY_BOOSTER}
            }

            -- Draw the tab rects
            love.graphics.setColor(g.COLORS.UI.MAIN[theme].CARD)
            love.graphics.rectangle("fill", listR:get())
            for k, v in pairs(tabs) do
                -- Input test
                if iml.wasJustClicked(v[1]:get()) then
                    self.activeTab = k
                end
                -- Distinct active tab with inactive tabs
                if self.activeTab == k then
                    love.graphics.setColor(g.COLORS.UI.MAIN[theme].CARD)
                else
                    love.graphics.setColor(g.COLORS.UI.MAIN[theme].TAB_INACTIVE)
                end
                -- Draw trapezoid using the padding
                do
                    local x, y, w, h = v[1]:get()
                    love.graphics.polygon("fill", {
                        x + TRAPEZOID_PADDING, y,
                        x + w - TRAPEZOID_PADDING, y,
                        x + w, y + h,
                        x, y + h,
                    })
                end
                -- Draw tab name
                love.graphics.setColor(g.COLORS.UI.MAIN[theme].TEXT)
                ui.printRichInRegion(v[2], tabF, v[1], true, "center")
            end

            -- Get item list to be drawn
            ---@type g.ItemInfo[] contains unlocked items
            local items = {}
            for _, v in ipairs(g.ITEMS) do
                if g.isItemUnlocked(v) then
                    local itemInfo, cat = g.getItemInfo(v)
                    if cat == self.activeTab then
                        items[#items+1] = itemInfo
                    end
                end
            end

            -- Draw item list
            local itemListR = listR:padUnit(4)
            local itemListRectSize = math.min(itemListR.w, itemListR.h)
            local itemListGrid, totalWidth = generateItemListRegion(itemListR, #items, itemListRectSize, 4)
            local scrollSize = math.max(itemListR.w - totalWidth, 0)
            local itemNameF = g.getMainFont(10)
            local showDescriptionOf = nil
            local gotDrag = nil
            -- TODO: Draw scrollbar
            for i, itemBaseR in ipairs(itemListGrid) do
                local itemPlacementR, itemNameR = helper.splitRegionByExactSizes(itemBaseR, "vertical", 0, itemNameF:getHeight() * 2)
                local itemInfo = items[i]
                local x, y, w, h = itemBaseR:get()

                -- Oli: Check drag first for proper behavior!
                local drag = iml.consumeDrag(itemInfo, x, y, w, h, 1)
                if drag or iml.isClicked(x, y, w, h, 1, itemInfo) then
                    showDescriptionOf = {itemBaseR.x + itemBaseR.w / 2, itemBaseR.y, itemInfo}

                    if self.activeDragging and self.activeDragging[2] ~= itemInfo or not self.activeDragging then
                        self.activeDragging = {0, itemInfo}
                    end
                    gotDrag = self.activeDragging
                else
                    if iml.isHovered(x, y, w, h, itemInfo) then
                        love.graphics.setColor(helper.multiplyAlpha(g.COLORS.UI.MAIN[theme].TEXT, 0.2))
                        love.graphics.rectangle("fill", itemBaseR:get())
                        showDescriptionOf = {itemBaseR.x + itemBaseR.w / 2, itemBaseR.y, itemInfo}
                    end
                end

                -- Draw actual item
                local col = gsman.setColor(1, 1, 1)
                local itemR = itemPlacementR:padRatio(0.1):shrinkToAspectRatio(1, 1):center(itemPlacementR)
                itemInfo.drawItem(itemR)
                col:pop()

                -- Draw item name
                do
                    local _, l = itemNameF:getWrap(itemInfo.name, itemNameR.w)
                    local oy = (itemNameR.h - itemNameF:getHeight() * #l) / 2
                    col = gsman.setColor(g.COLORS.UI.MAIN[theme].TEXT)
                    love.graphics.printf(itemInfo.name, itemNameF, itemNameR.x, itemNameR.y + oy, itemNameR.w, "center")
                    col:pop()
                end
            end

            self.activeDragging = gotDrag
            love.graphics.setColor(1, 1, 1)

            if showDescriptionOf then
                ui.ItemTooltip.DrawHUDTooltip(showDescriptionOf[3], showDescriptionOf[1], showDescriptionOf[2])
            end
        end

        -- Draw resource and stats (top area)
        if showStats then
            local _, moneyR, loadR, cpsR, _, hideButtonR, _, pauseButtonR = helper.splitRegionByExactSizes(
                self.topR, "horizontal",
                8, 144, 144, 144, 0, self.topR.h, 8, self.topR.h, 8
            )
            local lw2 = gsman.setLineWidth(1)
            local money = g.formatNumber(g.getResource("money")).."/"..g.formatNumber(g.getResourceLimit("money"))
            drawStats(moneyR, TEXT.MONEY, TEXT.MONEY_DESCRIPTION, "{money}", money)
            local loadColor = world.currentLoad > g.stats.MaxLoad and g.COLORS.UI.WARNING or objects.Color.WHITE
            drawStats(loadR, TEXT.LOAD, TEXT.LOAD_DESCRIPTION, "{bolt}", world.currentLoad.."/"..g.stats.MaxLoad, loadColor)
            drawStats(cpsR, TEXT.CPS, TEXT.CPS_DESCRIPTION, g.formatNumber(world.cpsCollector:getAverage()), "{dns}/s")
            lw2:pop()

            love.graphics.setColor(0, 0, 0)
            ui.debugRegion(hideButtonR)
            ui.debugRegion(pauseButtonR)
        end
    end

    lineWidth:pop()
    prof_pop() -- prof_push("HUD:draw")
end

function HUD:getSafeArea()
    local r = ui.getFullScreenRegion()

    local topY = self.topR.y + self.topR.h
    local leftX = self.leftR.x + self.leftR.w
    local width = r.w - leftX
    local height = self.botR.y - topY
    return r:set(leftX, topY, width, height)
end

return HUD
