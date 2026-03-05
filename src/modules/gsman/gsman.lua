-- Graphics state maanger

local love = require("love")

local gsman = {}

---@class gsman.LineWidth: objects.Class
local LineWidth = objects.Class("gsman.LineWidth")

---@param lw number
function LineWidth:init(lw)
    self.lw = love.graphics.getLineWidth()
    love.graphics.setLineWidth(lw)
end

function LineWidth:pop()
    love.graphics.setLineWidth(self.lw)
end

---@class gsman.Translate: objects.Class
local Translate = objects.Class("gsman.Translate")

---@param x number
---@param y number
function Translate:init(x, y)
    self.x = x
    self.y = y
    love.graphics.translate(x, y)
end

function Translate:pop()
    love.graphics.translate(-self.x, -self.y)
end

---@param lw number
---@return gsman.LineWidth
---@nodiscard
function gsman.setLineWidth(lw)
    return LineWidth(lw)
end

---@param x number
---@param y number
---@return gsman.Translate
---@nodiscard
function gsman.translate(x, y)
    return Translate(x, y)
end

return gsman
