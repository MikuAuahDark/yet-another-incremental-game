-- Graphics state maanger

local love = require("love")

---@class gsman
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

---@class gsman.Color: objects.Class
local Color = objects.Class("gsman.Color")

---@param r number
---@param g number
---@param b number
---@param a number
---@param mul boolean
function Color:init(r, g, b, a, mul)
    self.r, self.g, self.b, self.a = love.graphics.getColor()
    if mul then
        love.graphics.setColor(self.r * r, self.g * g, self.b * b, self.a * a)
    else
        love.graphics.setColor(r, g, b, a)
    end
end

function Color:pop()
    love.graphics.setColor(self.r, self.g, self.b, self.a)
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

---@param r number
---@param g number
---@param b number
---@param a number?
---@return gsman.Color
---@overload fun(color:objects.Color):gsman.Color
---@nodiscard
function gsman.setColor(r, g, b, a)
    if type(r) == "table" then
        return Color(r[1], r[2], r[3], r[4])
    else
        return Color(r, g, b, a or 1)
    end
end

---@param r number
---@param g number
---@param b number
---@param a number?
---@return gsman.Color
---@overload fun(color:objects.Color):gsman.Color
---@nodiscard
function gsman.mulColor(r, g, b, a)
    if type(r) == "table" then
        return Color(r[1], r[2], r[3], r[4], true)
    else
        return Color(r, g, b, a or 1, true)
    end
end

return gsman
