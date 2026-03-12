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

---@class gsman.Transform: objects.Class
local Transform = objects.Class("gsman.Transform")

---@param x number
---@param y number
---@param r number?
---@param sx number?
---@param sy number?
---@param ox number?
---@param oy number?
---@param kx number?
---@param ky number?
function Transform:init(x, y, r, sx, sy, ox, oy, kx, ky)
    love.graphics.push()
    love.graphics.applyTransform(x, y, r, sx, sy, ox, oy, kx, ky)
end

function Transform:pop()
    return love.graphics.pop()
end



---@param lw number
---@return gsman.LineWidth
---@nodiscard
function gsman.setLineWidth(lw)
    return LineWidth(lw)
end

---@param x number
---@param y number
---@return gsman.Transform
---@deprecated use gsman.transform instead
---@nodiscard
function gsman.translate(x, y)
    return Transform(x, y)
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

---@param x number
---@param y number
---@param r number?
---@param sx number?
---@param sy number?
---@param ox number?
---@param oy number?
---@param kx number?
---@param ky number?
---@return gsman.Transform
---@nodiscard
function gsman.transform(x, y, r, sx, sy, ox, oy, kx, ky)
    return Transform(x, y, r, sx, sy, ox, oy, kx, ky)
end

return gsman
