---@class ui.TooltipBuilder: objects.Class
---@field blocks table[]
---@field width number
---@field height number
---@field mx number
---@field my number
---@field ox number
---@field oy number
---@field safeArea kirigami.Region?
local TooltipBuilder = objects.Class("ui.TooltipBuilder")

local MAX_TOOLTIP_WIDTH = 200

---@param x number
---@param y number
---@param ox number
---@param oy number
---@param safeArea kirigami.Region?
function TooltipBuilder:init(x, y, ox, oy, safeArea)
    self.blocks = {}
    self.width = 120
    self.height = 0
    self.mx = x
    self.my = y
    self.ox = ox
    self.oy = oy
    self.safeArea = safeArea
end

if false then
    ---@param x number
    ---@param y number
    ---@param ox number
    ---@param oy number
    ---@param safeArea kirigami.Region?
    ---@return ui.TooltipBuilder
    ---@diagnostic disable-next-line: cast-local-type, missing-return
    function TooltipBuilder(x, y, ox, oy, safeArea) end
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
    local tdrawableR, tcntR = ui.getTooltipRegion(
        self.mx - self.width * self.ox,
        self.my - self.height * self.oy,
        self.width,
        self.height,
        self.safeArea
    )

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
