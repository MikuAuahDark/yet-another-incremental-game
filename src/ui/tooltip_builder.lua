---@class ui.TooltipBuilder: objects.Class
---@field blocks table[]
---@field width number
---@field height number
---@field mx number
---@field my number
---@field safeArea kirigami.Region?
---@field isHUD boolean
local TooltipBuilder = objects.Class("ui.TooltipBuilder")

local MAX_TOOLTIP_WIDTH = 200

---@param mode "world"|"hud"
---@param x number
---@param y number
---@param safeArea kirigami.Region?
function TooltipBuilder:init(mode, x, y, safeArea)
    self.blocks = {}
    self.width = 120
    self.height = 0
    self.mx = x
    self.my = y
    ---@type kirigami.Region?
    self.safeArea = nil
    self.isHUD = false

    if mode == "world" then
        self.safeArea = safeArea
    elseif mode == "hud" then
        self.isHUD = true
    end
end

if false then
    ---@param mode "world"|"hud"
    ---@param x number
    ---@param y number
    ---@param safeArea kirigami.Region?
    ---@return ui.TooltipBuilder
    ---@diagnostic disable-next-line: cast-local-type, missing-return
    function TooltipBuilder(mode, x, y, safeArea) end
end

---@param text string|richtext.ParsedText
---@param font love.Font
---@param align love.AlignMode?
---@param heightOverride number?
function TooltipBuilder:addText(text, font, align, heightOverride)
    local w, lines = richtext.getWrap(text, font, MAX_TOOLTIP_WIDTH)
    local h = heightOverride or (lines * font:getHeight())
    table.insert(self.blocks, {
        type = "text",
        text = text,
        font = font,
        align = align or "center",
        w = w,
        h = h
    })
    self.width = helper.clamp(self.width, w, MAX_TOOLTIP_WIDTH)
    self.height = self.height + h
    return self
end

---@param w number
function TooltipBuilder:ensureWidth(w)
    self.width = helper.clamp(self.width, w, MAX_TOOLTIP_WIDTH)
    return self
end

---@param h number
function TooltipBuilder:addPadding(h)
    table.insert(self.blocks, {
        type = "padding",
        h = h
    })
    self.height = self.height + h
    return self
end

---@param h number
---@param drawFn fun(x:number, y:number, w:number, h:number)
function TooltipBuilder:addCustom(h, drawFn)
    table.insert(self.blocks, {
        type = "custom",
        h = h,
        drawFn = drawFn
    })
    self.height = self.height + h
    return self
end

function TooltipBuilder:render()
    local tdrawableR, tcntR
    if self.isHUD then
        tdrawableR, tcntR = ui.getTooltipRegion(self.mx - self.width / 2, self.my - self.height, self.width, self.height)
    else
        tdrawableR, tcntR = ui.getTooltipRegion(self.mx, self.my, self.width, self.height, self.safeArea)
    end

    ui.Tooltip(tdrawableR, objects.Color.BLACK, objects.Color.WHITE)

    local currentY = tcntR.y
    for _, block in ipairs(self.blocks) do
        if block.type == "text" then
            richtext.printRich(block.text, block.font, tcntR.x, currentY, tcntR.w, block.align)
        elseif block.type == "custom" then
            block.drawFn(tcntR.x, currentY, tcntR.w, block.h)
        end
        currentY = currentY + block.h
    end
end

return TooltipBuilder
