local JobCard = require(".jobcard")

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

    ui.TooltipBuilder(x, y, 0.5, 0, ui.getFullScreenRegion(), MAX_TOOLTIP_WIDTH)
        :addText(title, titleF, "center")
        :addText(description, descF, "center")
        :render()
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
    self.activeTab = "server"
    self.scrollPos = 0

    self.wheelX = 0
    self.wheelY = 0

    self.wasVisibilityButtonPressed = false
    self.wasResetCameraButtonPressed = false

    ---@type string? itemID or empty string to delete (nil = no tool)
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

    self.wasVisibilityButtonPressed = false
    self.wasResetCameraButtonPressed = false
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
    local col2 = gsman.mulColor(col or objects.Color.WHITE)
    richtext.printRich(left, font, padR.x + 8, oy, padR.w, "left")
    richtext.printRich(right, font, padR.x - 8, oy, padR.w, "right")
    col2:pop()

    if iml.isHovered(padR:get()) then
        local col3 = gsman.setColor(1, 1, 1)
        drawTooltipWithDescription(padR.x + padR.w / 2, padR.y + padR.h + 8, title, desc)
        col3:pop()
    end
end


---@param cat g.ItemCategory
local function filterServer(cat)
    return cat == "server"
end
---@param cat g.ItemCategory
local function filterData(cat)
    return cat == "data" or cat == "indata"
end
---@param cat g.ItemCategory
local function filterBooster(cat)
    return cat == "booster"
end
---@param cat g.ItemCategory
local function filterPower(cat)
    return cat == "powergen" or cat == "powerrelay"
end


---@param show {stats:boolean?,jobQueue:boolean?,itemList:boolean?,mode?:"main"|"upgrade"}?
function HUD:draw(show)
    prof_push("HUD:draw")

    local showStats = nilIsTrue(show and show.stats)
    local showJobQueue = nilIsTrue(show and show.jobQueue)
    local showItemList = nilIsTrue(show and show.itemList)
    local mode = show and show.mode or "main"

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
            local unlockedJobCats = objects.Set() --[[@as objects.Set<g.JobCategory>]]
            for k, v in pairs(g.VALID_JOBS) do
                if world.jobPoller[k] and world.jobPoller[k][2] > 0 then
                    unlockedJobCats:add(v.category)
                end
            end

            local jobQueueKeyList = {TEXT.JOB_QUEUE_INFO}
            local jobQueueValueList = {""}
            for _, jobCat in ipairs(g.JOB_CATEGORIES) do
                if unlockedJobCats:contains(jobCat) then
                    local jobCatInfo = g.getJobCategoryInfo(jobCat)
                    local name = jobCatInfo.name
                    jobQueueKeyList[#jobQueueKeyList+1] = name
                    jobQueueValueList[#jobQueueValueList+1] = "+"..g.formatNumber(g.stats[jobCatInfo.nameRaw.."JobFrequency"]).."J/s"
                end
            end

            local jobQueueF = g.getMainFont(12)
            local jobQueueKeyText = table.concat(jobQueueKeyList, "\n")
            local jobQueueValueText = table.concat(jobQueueValueList, "\n")
            -- TODO: Add scrollbars
            local jobTextR, jobQR = helper.splitRegionByExactSizes(
                self.leftR:padUnit(4, 4, 4, 0),
                "vertical",
                jobQueueF:getHeight() * #jobQueueKeyList,
                0
            )

            -- Draw job queue text
            love.graphics.setColor(g.COLORS.UI.MAIN[theme].TEXT)
            ui.printRichInRegion(jobQueueKeyText, jobQueueF, jobTextR, true, "left", "top")
            ui.printRichInRegion(jobQueueValueText, jobQueueF, jobTextR, true, "right", "top")

            -- Draw job card
            if world.htx and world.hty then
                local item = g.getItem(world.htx, world.hty)
                if item then
                    local _, cat = g.getItemInfo(item.type)
                    local wires = nil
                    local height = 0
                    local PAD_W = 4
                    local PAD_H = 4
                    local lw = gsman.setLineWidth(1)

                    if cat == "server" then
                        ---@cast item g.World.ServerData
                        wires = item.connectedInputs

                        -- Always render current processed job on top
                        if item.currentJob then
                            local jobCard = JobCard(item.currentJob, item.dataTotalEmitted / item.currentJob.outputData)
                            local jobCardHeight = jobCard:getHeight(jobQR.w - PAD_W * 2) + 2 * PAD_H
                            jobCard:render(theme, jobQR.x + PAD_W, jobQR.y + height + PAD_H, jobQR.w - PAD_W * 2)
                            love.graphics.rectangle("line", jobQR.x, jobQR.y + height, jobQR.w, jobCardHeight, 2, 2)
                            height = height + jobCardHeight
                        end
                    elseif cat == "indata" then
                        ---@cast item g.World.DataInputData
                        wires = item.connects
                    end

                    if wires then
                        local stop = false

                        for _, wire in ipairs(wires) do
                            for _, job in ipairs(wire.objects) do
                                local jobCard = JobCard(job)
                                local jobCardHeight = jobCard:getHeight(jobQR.w - PAD_W * 2) + 2 * PAD_H
                                if (jobCardHeight + height) > jobQR.h then
                                    stop = true
                                    break
                                end

                                jobCard:render(theme, jobQR.x + PAD_W, jobQR.y + height + PAD_H, jobQR.w - PAD_W * 2)
                                love.graphics.rectangle("line", jobQR.x, jobQR.y + height, jobQR.w, jobCardHeight, 2, 2)
                                height = height + jobCardHeight + 2 * PAD_H
                            end

                            if stop then
                                break
                            end
                        end
                    end

                    lw:pop()
                end
            end

            -- Should we render job queue info?
            if iml.isHovered(jobTextR:get()) then
                -- Request info
                local descF = g.getMainFont(10)
                ---@type g.JobInfo[]
                local jobs = {}
                for k, v in pairs(g.VALID_JOBS) do
                    if world.jobPoller[k] and world.jobPoller[k][2] > 0 then
                        jobs[#jobs+1] = v
                    end
                end

                if #jobs > 0 then
                    table.sort(jobs, function(a, b) return a.id < b.id end)
                    local height = descF:getHeight() * #jobs

                    local maxNameWidth = 0
                    local jpsMaxWidth = 0
                    for _, ji in ipairs(jobs) do
                        local w = richtext.getWidth(ji.name, descF)
                        maxNameWidth = math.max(maxNameWidth, w)
                        local jps = g.formatNumber(world.jobPoller[ji.id][2])
                        local jpsW = richtext.getWidth(jps.." J/s", descF)
                        jpsMaxWidth = math.max(jpsMaxWidth, jpsW)
                    end

                    local width = 8 + maxNameWidth + jpsMaxWidth
                    local mx, my = ui.getMouse()
                    local tdrawableR, tcntR = ui.getTooltipRegion(mx + 8, my + 8, width, height, ui.getFullScreenRegion())

                    local nameListR, _, jpsListR = helper.splitRegionByExactSizes(tcntR, "horizontal", maxNameWidth, 8, jpsMaxWidth)
                    local nameG = nameListR:grid(1, #jobs)
                    local jpsG = jpsListR:grid(1, #jobs)

                    love.graphics.setColor(1, 1, 1)
                    ui.Tooltip(tdrawableR, objects.Color.BLACK, objects.Color.WHITE)

                    for i, ji in ipairs(jobs) do
                        local nameR = nameG[i]
                        local jpsR = jpsG[i]
                        local jps = g.formatNumber(world.jobPoller[ji.id][2]).." J/s"
                        ui.printRichInRegion(ji.name, descF, nameR, true)
                        ui.printRichInRegion(jps, descF, jpsR, true)
                    end
                end
            end
        end

        if showItemList then
            -- Draw item list
            local TRAPEZOID_PADDING = 10
            local tabR, listR, scrollR = helper.splitRegionByExactSizes(self.botR:padUnit(1), "vertical", tabF:getHeight(), 0, 10)
            local serversTabR, dataTabR, boostersTabR, powerTabR = helper.splitRegionByExactSizes(
                tabR, "horizontal",
                tabF:getWidth(TEXT.CATEGORY_SERVER) + 2 * (TRAPEZOID_PADDING + 1),
                tabF:getWidth(TEXT.CATEGORY_DATA) + 2 * (TRAPEZOID_PADDING + 1),
                tabF:getWidth(TEXT.CATEGORY_BOOSTER) + 2 * (TRAPEZOID_PADDING + 1),
                tabF:getWidth(TEXT.CATEGORY_POWER) + 2 * (TRAPEZOID_PADDING + 1),
                0
            )
            ---@type table<string, [(fun(cat:g.ItemCategory):boolean), kirigami.Region, string]>
            local tabs = {
                server = {filterServer, serversTabR, TEXT.CATEGORY_SERVER},
                data = {filterData, dataTabR, TEXT.CATEGORY_DATA},
                booster = {filterBooster, boostersTabR, TEXT.CATEGORY_BOOSTER},
                power = {filterPower, powerTabR, TEXT.CATEGORY_POWER}
            }

            -- Draw the tab rects
            love.graphics.setColor(g.COLORS.UI.MAIN[theme].CARD)
            for k, v in pairs(tabs) do
                -- Input test
                if iml.wasJustClicked(v[2]:get()) then
                    self.activeTab = k
                    self.selectedItem = nil
                end
                -- Distinct active tab with inactive tabs
                if self.activeTab == k then
                    love.graphics.setColor(g.COLORS.UI.MAIN[theme].CARD)
                else
                    love.graphics.setColor(g.COLORS.UI.MAIN[theme].TAB_INACTIVE)
                end
                -- Draw trapezoid using the padding
                do
                    local x, y, w, h = v[2]:get()
                    love.graphics.polygon("fill", {
                        x + TRAPEZOID_PADDING, y,
                        x + w - TRAPEZOID_PADDING, y,
                        x + w, y + h,
                        x, y + h,
                    })
                end
                -- Draw tab name
                love.graphics.setColor(g.COLORS.UI.MAIN[theme].TEXT)
                ui.printRichInRegion(v[3], tabF, v[2], true, "center")
            end

            -- Get item list to be drawn
            ---@type g.ItemInfo[] contains unlocked items
            local items = {}
            for _, v in ipairs(g.ITEMS) do
                if g.isItemUnlocked(v) then
                    local itemInfo, cat = g.getItemInfo(v)
                    if tabs[self.activeTab][1](cat) then
                        items[#items+1] = itemInfo
                    end
                end
            end

            -- Draw item list
            local itemListBaseR = listR:padUnit(4)
            local itemListR, deleteButtonR = helper.splitRegionByExactSizes(
                itemListBaseR,
                "horizontal",
                0,
                math.min(itemListBaseR.w, itemListBaseR.h)
            )
            local itemListRectSize = math.min(itemListR.w, itemListR.h)
            local itemListGrid, totalWidth = generateItemListRegion(itemListR, #items, itemListRectSize, 4)
            local scrollSize = math.max(totalWidth - itemListR.w, 0)
            local itemNameF = g.getMainFont(10)
            local inventoryF = g.getThickFont(14)
            local showDescriptionOf = nil

            if totalWidth > itemListR.w then
                -- Update scrollbar
                if itemListR:containsCoords(ui.getMouse()) then
                    local dx, dy = iml.consumeWheelMove()
                    if dx and dy then
                        -- Discreteize
                        self.wheelX = self.wheelX + dx
                        self.wheelY = self.wheelY + dy
                        local newdx = helper.round(self.wheelX)
                        local newdy = helper.round(self.wheelY)
                        self.wheelX = self.wheelX - newdx
                        self.wheelY = self.wheelY - newdy

                        local dir = newdx - newdy
                        if dir ~= 0 then
                            self.scrollPos = self.scrollPos + dir * 10
                        end
                    end
                end

                -- Draw scrollbar
                local actualScrollR = scrollR:padUnit(2)
                local newScroll = ui.Slider(
                    "huditemscroll",
                    "horizontal",
                    g.COLORS.UI.MAIN[theme].PRIMARY_INVERT,
                    helper.clamp(self.scrollPos + 1, 1, scrollSize + 1),
                    scrollSize + 1,
                    0.2,
                    actualScrollR
                ) - 1
                self.scrollPos = newScroll
            else
                self.scrollPos = 0
                self.wheelX = 0
                self.wheelY = 0
            end

            -- Draw item list area
            love.graphics.setColor(g.COLORS.UI.MAIN[theme].CARD)
            love.graphics.setStencilMode("draw", 2)
            love.graphics.setColorMask(true, true, true, true)
            love.graphics.rectangle("fill", itemListR:get())
            love.graphics.setStencilMode("test", 2)
            love.graphics.setColor(1, 1, 1)

            -- Draw individual items
            for i, itemBaseR in ipairs(itemListGrid) do
                -- If itemBaseR is completely invisible, don't bother rendering it
                itemBaseR = itemBaseR:moveUnit(-self.scrollPos, 0)
                local clickAreaR = itemListR:intersection(itemBaseR)
                if clickAreaR:exists() then
                    local itemPlacementR, itemNameR = helper.splitRegionByExactSizes(itemBaseR, "vertical", 0, itemNameF:getHeight() * 2)
                    local itemInfo = items[i]
                    local x, y, w, h = clickAreaR:get()
                    local inventory = g.getItemInventoryCount(itemInfo.id)

                    if iml.isHovered(x, y, w, h, itemInfo) then
                        love.graphics.setColor(helper.multiplyAlpha(g.COLORS.UI.MAIN[theme].TEXT, 0.2))
                        love.graphics.rectangle("fill", itemBaseR:get())
                        showDescriptionOf = {itemBaseR.x + itemBaseR.w / 2, itemBaseR.y, itemInfo}
                    end

                    local col
                    if inventory > 0 then
                        if iml.wasJustClicked(x, y, w, h, 1, itemInfo) then
                            if self.selectedItem == itemInfo.id then
                                self.selectedItem = nil
                            else
                                self.selectedItem = itemInfo.id
                            end
                        end
                        col = gsman.setColor(1, 1, 1)
                    else
                        col = gsman.setColor(0.5, 0.5, 0.5)
                    end

                    -- Draw actual item
                    local itemR = itemPlacementR:padRatio(0.1):shrinkToAspectRatio(1, 1):center(itemPlacementR)
                    itemInfo.drawItem(itemR)
                    col:pop()

                    -- Draw inventory quantity
                    do
                        if inventory > 0 then
                            col = gsman.setColor(0.1, 0.7, 0)
                        else
                            col = gsman.setColor(0.7, 0.1, 0.1)
                        end

                        local txt = tostring(inventory)
                        local invW = inventoryF:getWidth(txt)
                        helper.printTextOutlineSimple(
                            txt,
                            inventoryF, 0.7,
                            itemPlacementR.x + itemPlacementR.w - invW - 4,
                            itemPlacementR.y + itemPlacementR.h - inventoryF:getHeight()
                        )
                        col:pop()
                    end

                    -- Draw item name
                    do
                        local _, l = itemNameF:getWrap(itemInfo.name, itemNameR.w)
                        local oy = (itemNameR.h - itemNameF:getHeight() * #l) / 2
                        col = gsman.setColor(g.COLORS.UI.MAIN[theme].TEXT)
                        love.graphics.printf(itemInfo.name, itemNameF, itemNameR.x, itemNameR.y + oy, itemNameR.w, "center")
                        col:pop()
                    end
                end
            end

            love.graphics.setStencilMode()


            -- Draw delete or cancel button
            love.graphics.setColor(1, 0.1, 0.1)
            local deleteButtonAreaR = deleteButtonR:padRatio(0.3)
            if self.selectedItem then
                g.drawImageContained("cancel", deleteButtonAreaR:get())
            else
                g.drawImageContained("delete", deleteButtonAreaR:get())
            end
            if ui.region.wasJustClicked(deleteButtonR) then
                if self.selectedItem then
                    self.selectedItem = nil
                else
                    self.selectedItem = ""
                end
            end

            love.graphics.setColor(1, 1, 1)
            if showDescriptionOf then
                ui.ItemTooltip.DrawHUDTooltip(
                    showDescriptionOf[3],
                    showDescriptionOf[1],
                    showDescriptionOf[2],
                    ui.getFullScreenRegion()
                )
            end
        end

        -- Draw resource and stats (top area)
        if showStats then
            local _, moneyR, cpsR, _, resetCameraR, _, hideButtonR, _, pauseButtonR = helper.splitRegionByExactSizes(
                self.topR, "horizontal",
                8, 144, 144, 0, self.topR.h, 8, self.topR.h, 8, self.topR.h, 8
            )
            local lw2 = gsman.setLineWidth(1)
            local money = g.getResource("money")
            local maxMoney = g.getResourceLimit("money")
            local moneyText = g.formatNumber(money).."/"..g.formatNumber(maxMoney)

            if money >= maxMoney then
                love.graphics.setColor(g.COLORS.UI.DEBUFF)
            else
                love.graphics.setColor(1, 1, 1)
            end
            drawStats(moneyR, TEXT.MONEY, TEXT.MONEY_DESCRIPTION, "{money}", moneyText)

            local cps = world.averageCPS
            if cps >= 1e9 then
                love.graphics.setColor(g.COLORS.UI.BUFF)
            else
                love.graphics.setColor(1, 1, 1)
            end
            drawStats(
                cpsR,
                helper.wrapRichtextColor(g.COLORS.UI.TEXT_CPS, TEXT.CPS),
                TEXT.CPS_DESCRIPTION,
                g.formatNumber(cps),
                helper.wrapRichtextColor(g.COLORS.UI.TEXT_CPS, "{dns}/s")
            )
            lw2:pop()


            local sn = g.getSn()
            if sn.pauseReason == "debug" then
                love.graphics.setColor(1, 0, 0)
            else
                love.graphics.setColor(g.COLORS.UI.MAIN[theme].TEXT)
            end

            g.drawImageContained("pause", pauseButtonR:padRatio(0.15):get())
            if iml.wasJustClicked(pauseButtonR:get()) then
                sn:setPaused("button")
            elseif consts.DEV_MODE and iml.wasKeyJustReleased("p") then
                if sn.paused and sn.pauseReason == "debug" then
                    sn:setPaused()
                else
                    sn:setPaused("debug")
                end
            end

            love.graphics.setColor(g.COLORS.UI.MAIN[theme].TEXT)

            if mode == "main" then
                g.drawImageContained("visibility_off", hideButtonR:padRatio(0.15):get())
                self.wasVisibilityButtonPressed = iml.wasJustClicked(hideButtonR:get())

                g.drawImageContained("reset_focus", resetCameraR:padRatio(0.15):get())
                self.wasResetCameraButtonPressed = iml.wasJustClicked(resetCameraR:get())
            end
        end
    end

    lineWidth:pop()
    prof_pop() -- prof_push("HUD:draw")
end

---@param image string
---@param opacity number
function HUD:drawCancelIntuition(image, opacity)
    love.graphics.setColor(1, 0, 0, opacity * 0.25)
    love.graphics.rectangle("fill", self.botR:get())
    local imageR = self.botR:padRatio(0.5)
        :shrinkToAspectRatio(1, 1)
        :center(self.botR)
    love.graphics.setColor(1, 0, 0, opacity * 0.67)
    g.drawImageContained(image, imageR:get())
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
