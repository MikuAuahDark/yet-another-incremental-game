local objects = require("src.modules.objects.objects")


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
    ui.printRichInRegion(job.name, titleF, titleR, true, "left")
    ui.printRichInRegion(g.getJobCategoryName(job.category), catF, catR, true, "left")
    local computeR, dataR, moneyR = outR:splitHorizontal(1, 1, 1)
    ui.printRichInRegion(job.computePower.." Cm", titleF, computeR, true, "left")
    ui.printRichInRegion(job.outputData.." Dt", titleF, dataR, true, "center")
    -- We only have "money"
    -- FIXME: Change it if we have more than 1 resources
    ui.printRichInRegion("$"..assert(job.resource.money), titleF, moneyR, true, "right")

    -- Draw timeout bar
    local timeoutWidth = helper.clamp(job.timeout * r.w / math.max(getJobTimeout(job), 1), 0, r.w)
    love.graphics.rectangle("fill", r.x, r.y + r.h - 4, timeoutWidth, 4)
end

local function getJobCardHeight()
    local titleF = g.getMainFont(16)
    local catF = g.getMainFont(10)
    return 4 * 2 + titleF:getHeight() * 2 + catF:getHeight() + 4
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
        :set(nil, nil, nil, 96)
        :attachToBottomOf(r)
        :moveRatio(0, -1)

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
---@param left string
---@param right string
local function drawStats(r, left, right)
    local font = g.getMainFont(18)
    local padR = r:padUnit(4)

    love.graphics.setColor(0, 0, 0)
    local radius = math.min(padR.w, padR.h) / 2
    helper.quickRoundedRectangle("fill", radius, padR)
    helper.quickRoundedRectangle("line", radius, padR)

    local oy = padR.y + (padR.h - font:getHeight()) / 2
    love.graphics.setColor(1, 1, 1)
    love.graphics.printf(left, font, padR.x + 8, oy, padR.w, "left")
    love.graphics.printf(right, font, padR.x - 8, oy, padR.w, "right")
end

---@param show {resource:boolean?,profile:boolean?,xpbar:boolean?}?
function HUD:draw(show)
    prof_push("HUD:draw")

    local lineWidth = gsman.setLineWidth(2)
    local theme = g.getSystemTheme()
    local tabF = g.getMainFont(16)
    drawPanelWithBorder(self.topR, theme)
    drawPanelWithBorder(self.leftR, theme)
    drawPanelWithBorder(self.botR:padUnit(0, tabF:getHeight(), 0, 0), theme)

    if g.hasSession() then
        local world = g.getMainWorld()

        -- Draw resource and stats (top area)
        do
            local _, moneyR, loadR, cpsR, _, hideButtonR, _, pauseButtonR = helper.splitRegionByExactSizes(
                self.topR, "horizontal",
                8, 128, 128, 128, 0, self.topR.h, 8, self.topR.h, 8
            )
            local lw2 = gsman.setLineWidth(1)
            local money = g.formatNumber(g.getResource("money")).."/"..g.formatNumber(g.getResourceLimit("money"))
            drawStats(moneyR, "$", money)
            drawStats(loadR, "L", world.currentLoad.."/"..world.maxLoad)
            drawStats(cpsR, "123456", "C/s")
            lw2:pop()

            love.graphics.setColor(0, 0, 0)
            ui.debugRegion(hideButtonR)
            ui.debugRegion(pauseButtonR)
        end

        -- Draw job queue
        do
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
                maxjobs = g.ask("getMaxJobQueueModifier"),
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

        do
            -- Draw item list
            local TRAPEZOID_PADDING = 10
            local tabR, listR = helper.splitRegionByExactSizes(self.botR:padUnit(1), "vertical", tabF:getHeight(), 0)
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
