local objects = require("src.modules.objects.objects")


---@class g.HUD: objects.Class
---@field freeArea kirigami.Region
local HUD = objects.Class("g:HUD")

function HUD:init()
    self.sidebarR = Kirigami(0, 0, 1, 1)
    self.topR = Kirigami(0, 0, 1, 1)
    self.leftR = Kirigami(0, 0, 1, 1)
    self.botR = Kirigami(0, 0, 1, 1)
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
        :set(nil, nil, nil, 72)
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
    drawPanelWithBorder(self.topR, theme)
    drawPanelWithBorder(self.leftR, theme)
    drawPanelWithBorder(self.botR, theme)

    do
        -- Draw resource and stats
        local _, moneyR, loadR, cpsR, _, hideButtonR, _, pauseButtonR = helper.splitRegionByExactSizes(
            self.topR, "horizontal",
            8, 128, 128, 128, 0, self.topR.h, 8, self.topR.h, 8
        )
        local lw2 = gsman.setLineWidth(1)
        drawStats(moneyR, "$", "123/456")
        drawStats(loadR, "Load", "95/100")
        drawStats(cpsR, "123456", "C/s")
        lw2:pop()

        love.graphics.setColor(0, 0, 0)
        ui.debugRegion(hideButtonR)
        ui.debugRegion(pauseButtonR)
    end

    local font = g.getMainFont(12)
    love.graphics.setColor(g.COLORS.UI.MAIN[theme].TEXT)
    richtext.printRichContained("Job queue here", font, self.leftR:get())
    richtext.printRichContained("Buildings here", font, self.botR:get())

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
