---@class g.WorldUtil
local worldutil = {}





g.defineEntity("SHOCKWAVE_ANIMATION", {
    drawOrder = 100,
    draw = function (ent)
        ---@diagnostic disable-next-line
        local dur = ent._duration
        ---@diagnostic disable-next-line
        local maxRad = ent._maxRad
        ---@diagnostic disable-next-line
        local c = ent._color or objects.Color.WHITE

        local rad = helper.remap(ent.lifetime, dur,0, 7, maxRad)
        local alpha = ent.lifetime/dur
        lg.setColor(c[1],c[2],c[3], math.sqrt(alpha))

        local lw=lg.getLineWidth()
        lg.setLineWidth(maxRad/4)
        lg.push()
        lg.circle("line", ent.x,ent.y, rad,rad)
        lg.pop()
        lg.setLineWidth(lw)
    end
})

---@param x number
---@param y number
---@param duration number
---@param radius number?
---@param color (objects.Color|[number,number,number,number?])?
function worldutil.spawnShockwave(x, y, duration, radius, color)
    if g.isBeingSimulated() then
        return -- dont shockwave when simulation mode
    end
    local e = g.spawnEntity("SHOCKWAVE_ANIMATION", x, y)
    ---@diagnostic disable-next-line
    e._duration = duration
    ---@diagnostic disable-next-line
    e._maxRad = radius or 20
    e._color = color or objects.Color.WHITE
    e.lifetime = duration
end



g.defineEntity("TEXT_ANIMATION", {
    drawOrder = 100,
    shadow = false,
    draw = function(ent)
        ---@diagnostic disable-next-line
        local dur = ent._duration
        ---@diagnostic disable-next-line
        local text = ent._text
        ---@diagnostic disable-next-line
        local moveDistance = ent._moveDistance

        local yOffset = helper.remap(math.max(ent.lifetime*2-dur, 0), dur,0, 0, moveDistance)
        local alpha = 1

        lg.setColor(1, 1, 1, alpha)
        local f = g.getMainFont(16)
        local sc = 1.2
        richtext.printRichCentered(text, assert(f), ent.x, ent.y - yOffset, 5000, "left", 0, sc)
    end
})

---@param text string
---@param x number
---@param y number
---@param duration number?
---@param moveDistance number?
function worldutil.spawnText(text, x, y, duration, moveDistance)
    if g.isBeingSimulated() then
        return -- dont spawn text when simulation mode
    end
    local e = g.spawnEntity("TEXT_ANIMATION", x, y)
    ---@diagnostic disable-next-line
    e._text = text
    ---@diagnostic disable-next-line
    e._duration = duration or 1.0
    ---@diagnostic disable-next-line
    e._moveDistance = moveDistance or 20
    e.lifetime = duration or 1.0
end





g.defineEntity("line", {
    draw = function(ent)
        ---@diagnostic disable-next-line: undefined-field
        local t = ent.lifetime / ent._duration
        local col = {love.graphics.getColor()}
        ---@diagnostic disable-next-line: undefined-field
        love.graphics.setColor(ent._color)
        g.drawImage("1x1", ent.x, ent.y, ent.rot, ent.sx, ent.sy * t)
        love.graphics.setColor(col)
    end
})

---@param x1 number
---@param y1 number
---@param x2 number
---@param y2 number
---@param width number
---@param color objects.Color
---@param duration number
function worldutil.spawnFadingLine(x1, y1, x2, y2, width, color, duration)
    local ent = g.spawnEntity("line", (x1 + x2) / 2, (y1 + y2) / 2)
    ent.sx = helper.magnitude(x2 - x1, y2 - y1)
    ent.sy = width
    ent.rot = math.atan2(y2 - y1, x2 - x1)
    ent.lifetime = duration
    ---@diagnostic disable-next-line: inject-field
    ent._color = color
    ---@diagnostic disable-next-line: inject-field
    ent._duration = duration
    return ent
end




local UNDERLIGHT_MESH = love.graphics.newMesh({
    {0, 0, 0.5, 0.5, 1, 1, 1, 1}, -- center
    {-0.5, -0.5, 0, 0, 0, 0, 0, 1}, -- top left
    {0.5, -0.5, 1, 0, 0, 0, 0, 1}, -- top right
    {0.5, 0.5, 1, 1, 0, 0, 0, 1}, -- bottom right
    {-0.5, 0.5, 0, 1, 0, 0, 0, 1}, -- bottom left
}, "fan", "static")
UNDERLIGHT_MESH:setVertexMap({1, 2, 3, 4, 5, 2})

---Light color is set by `love.graphics.setColor`.
---@param x number
---@param y number
---@param size number
function worldutil.drawUnderLightIndicator(x, y, size)
    love.graphics.draw(UNDERLIGHT_MESH, x, y, 0, size, size)
end





---Makes a rhombus pattern
---@param iteration integer
---@return [integer,integer][]
local function taxicabSpread(iteration)
    if iteration == 0 then
        return {{0, 0}}
    end

    local result = {}
    for dy = -iteration, iteration do
        for dx = -iteration, iteration do
            if math.abs(dx) + math.abs(dy) <= iteration then
                result[#result+1] = {dx, dy}
            end
        end
    end
    return result
end

---Makes a square pattern
---@param iteration integer
---@return [integer,integer][]
local function chessboardSpread(iteration)
    if iteration == 0 then
        return {{0, 0}}
    end

    local result = {}
    for dy = -iteration, iteration do
        for dx = -iteration, iteration do
            if math.max(math.abs(dx), math.abs(dy)) <= iteration then
                result[#result+1] = {dx, dy}
            end
        end
    end
    return result
end

---@type table<g.RadiateAlgorithm, fun(iteration:integer):[integer,integer][]>
local RADIANCE_ALGORITHM = {
    taxicab = helper.memoize(taxicabSpread),
    chessboard = helper.memoize(chessboardSpread),
}

---@type table<g.RadiateAlgorithm, fun(ox:integer, oy:integer):integer>
local DISTANCER_ALGORITHM = {
    taxicab = function(ox, oy) return math.abs(ox) + math.abs(oy) end,
    chessboard = function(ox, oy) return math.max(math.abs(ox), math.abs(oy)) end,
}

---@param algo g.RadiateAlgorithm
---@param spread integer
function worldutil.getSpreadTiles(algo, spread)
    return RADIANCE_ALGORITHM[algo](spread)
end

---@param algo g.RadiateAlgorithm
---@param ox integer Relative
---@param oy integer Relative
function worldutil.getDistance(algo, ox, oy)
    return DISTANCER_ALGORITHM[algo](ox, oy)
end



---@param r kirigami.Region
---@param col objects.Color
local function drawServerShape(r, col)
    local DIAGONAL_PERCENTAGE = 0.2
    local x, y, w, h = r:get()
    local dpw = DIAGONAL_PERCENTAGE * w
    local dph = DIAGONAL_PERCENTAGE * h
    ---@type number[]
    local polygons = {
		-- Top
		x + dpw, y,
		x + w - dpw, y,
		-- Right
		x + w, y + dph,
		x + w, y + h - dph,
		-- Bottom
		x + w - dpw, y + h,
		x + dpw, y + h,
		-- Left
		x, y + h - dph,
		x, y + dph,
	}
    local c = gsman.mulColor(col)
    love.graphics.polygon("fill", polygons)
    c:pop()
end

---@param r kirigami.Region
---@param col objects.Color
function worldutil.drawServerShape(r, col)
    r = r:shrinkToAspectRatio(1, 1):center(r)
    local MOVE_DIST = 0.1
    local h, s, v = col:getHSV()
    local r1 = r:moveRatio(0, MOVE_DIST)
    local r2 = r:moveRatio(0, -MOVE_DIST)
    drawServerShape(r1, objects.Color(objects.Color.HSVtoRGB(h, s, v * 0.5)))
    drawServerShape(r2, col)
    return r2
end

---@param r kirigami.Region
---@param col objects.Color
local function drawDPShape(r, col)
    local cx, cy = r:getCenter()
    local rx = r.w / 2
    local ry = r.h / 2
    local polygons = {}
    for i = 0, 5 do
        local a = (i * math.pi) / 3 - math.pi / 2
        polygons[#polygons+1] = cx + rx * math.cos(a)
        polygons[#polygons+1] = cy + ry * math.sin(a)
    end
    local c = gsman.mulColor(col)
    love.graphics.polygon("fill", polygons)
    c:pop()
end

---@param r kirigami.Region
---@param col objects.Color
function worldutil.drawDPShape(r, col)
    r = r:shrinkToAspectRatio(1, 1):center(r)
    local MOVE_DIST = 0.1
    local h, s, v = col:getHSV()
    local r1 = r:moveRatio(0, MOVE_DIST)
    local r2 = r:moveRatio(0, -MOVE_DIST)
    drawDPShape(r1, objects.Color(objects.Color.HSVtoRGB(h, s, v * 0.5)))
    drawDPShape(r2, col)
    return r2
end

---@param r kirigami.Region
---@param col objects.Color
function worldutil.drawBoosterShape(r, col)
    r = r:shrinkToAspectRatio(1, 1):center(r)
    local MOVE_DIST = 0.1
    local h, s, v = col:getHSV()
    local r1 = r:moveRatio(0, MOVE_DIST)
    local r2 = r:moveRatio(0, -MOVE_DIST)
    local height = r2.y - (r1.y + r1.h)

    local col1 = gsman.mulColor(objects.Color.HSVtoRGB(h, s, v * 0.5))
    -- Draw rectangle
    love.graphics.rectangle("fill", r.x, r.y - height / 2, r.w, height)
    -- Draw arc
    love.graphics.arc("fill", "closed", r.x, r.y + height / 2, r.w / 2, math.pi, -math.pi)
    col1:pop()
    -- Draw circle
    local col2 = gsman.mulColor(col)
    love.graphics.circle("fill", r.x + r.w / 2, r.y + r.h / 2, r.w / 2)
    col2:pop()
    return r2
end



return worldutil
