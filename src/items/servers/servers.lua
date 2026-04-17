---@param numLines integer
---@param thicknessRatio number?
local function makeLineDrawerForServer(numLines, thicknessRatio)
    -- The draw area is 0.2-0.8
    local thickness = thicknessRatio or 0.1
    local placements = {} -- from [0, 1]
    -- Divide it equally by numLines
    -- I'm too lazy to get formula for it so just abuse Kirigami
    local r0 = Kirigami(0, 0, 1, 1)
    for i = 1, numLines * 2 + 1 do
        placements[#placements+1] = 1
    end
    local regions = {r0:splitHorizontal(unpack(placements))}
    ---@type number[]
    local pos = {}
    for i = 1, numLines do
        pos[#pos+1] = regions[i*2]:getCenter()
    end

    ---@param r kirigami.Region
    return function(r)
        local centerR = r:padRatio(0.5)
        local width = thickness * math.sqrt(centerR.w * centerR.h)

        for _, p in ipairs(pos) do
            -- Top
            local x = centerR.x + centerR.w * p - width / 2
            local h = centerR.y - r.y
            love.graphics.rectangle("fill", x, r.y, width, h)
            -- Right
            local y = centerR.y + centerR.h * p - width / 2
            local w = r.x + r.w - centerR.x - centerR.w
            love.graphics.rectangle("fill", centerR.x + centerR.w, y, w, width)
            -- Bottom
            love.graphics.rectangle("fill", x, centerR.y + centerR.h, width, h)
            -- Left
            love.graphics.rectangle("fill", r.x, y, w, width)
        end

        return centerR
    end
end



local _basicServerDecor = makeLineDrawerForServer(1)
g.defineServer("basic_server", "Basic Server", {
    description = "First one is free for startups.",
    price = 1,
    getPriceMultiplier = function(count)
        if count < 1 then return 0 end -- first 1 is free
        return (count - 1) / 10 + 1
    end,
    computePerSecond = 1,
    computePreference = {"general"},
    load = 1,
    heatTolerance = {40, 60},
    heat = 40,
    color = objects.Color("#ebe8c1"),
    draw = function(r)
        local col = gsman.mulColor(0, 0, 0)
        _basicServerDecor(r)
        col:pop()
    end,
})
g.PREUNLOCKED_ITEMS:add("basic_server")

local _tier1Server = makeLineDrawerForServer(2)
g.defineServer("normal_server", "Server (Tier 1)", {
    price = 75,
    getPriceMultiplier = helper.valueGetterNoSelf(0.05, 1),
    computePerSecond = 10,
    computePreference = {"general"},
    load = 4,
    heatTolerance = {40, 60},
    heat = 40,
    color = objects.Color("#ebe883"),
    draw = function(r)
        local col = gsman.mulColor(0, 0, 0)
        _tier1Server(r)
        col:pop()
    end,
})

local _tier2Server = makeLineDrawerForServer(3)
g.defineServer("tier2_server", "Server (Tier 2)", {
    price = 250,
    getPriceMultiplier = helper.valueGetterNoSelf(0.05, 1),
    computePerSecond = 35,
    computePreference = {"general"},
    load = 6,
    heatTolerance = {30, 70},
    heat = 40,
    color = objects.Color("#ebe883"),
    draw = function(r)
        local col = gsman.mulColor(0, 0, 0)
        _tier2Server(r)
        col:pop()
    end,
})

local _tier3Server = makeLineDrawerForServer(4)
g.defineServer("tier3_server", "Server (Tier 3)", {
    price = 700,
    getPriceMultiplier = helper.valueGetterNoSelf(0.05, 1),
    computePerSecond = 256,
    computePreference = {"general"},
    load = 10,
    heatTolerance = {20, 90},
    heat = 40,
    color = objects.Color("#ebe883"),
    draw = function(r)
        local col = gsman.mulColor(0, 0, 0)
        _tier3Server(r)
        col:pop()
    end
})



g.defineServer("advanced_server", "Video Server (Tier 1)", {
    price = 500,
    getPriceMultiplier = helper.valueGetterNoSelf(0.1, 1),
    computePerSecond = 30,
    computePreference = {"video"},
    load = 5,
    heatTolerance = {40, 60},
    heat = 50,
    color = objects.Color("#12aae6"),
    draw = function(r)
        local col = gsman.setColor(0, 0, 0)
        g.drawImageContained("movie", _tier1Server(r):get())
        col:pop()
    end,
})

g.defineServer("video2_server", "Video Server (Tier 2)", {
    price = 1100,
    getPriceMultiplier = helper.valueGetterNoSelf(0.1, 1),
    computePerSecond = 400,
    computePreference = {"video"},
    load = 12,
    heatTolerance = {30, 70},
    heat = 40,
    color = objects.Color("#12aae6"),
    draw = function(r)
        local col = gsman.setColor(0, 0, 0)
        g.drawImageContained("movie", _tier2Server(r):get())
        col:pop()
    end,
})

g.defineServer("video3_server", "Video Server (Tier 3)", {
    price = 2000,
    getPriceMultiplier = helper.valueGetterNoSelf(0.1, 1),
    computePerSecond = 1000,
    computePreference = {"video"},
    load = 20,
    heatTolerance = {30, 70},
    heat = 30,
    color = objects.Color("#12aae6"),
    draw = function(r)
        local col = gsman.setColor(0, 0, 0)
        local centerR = _tier3Server(r)
        g.drawImageContained("movie", centerR:get())
        col:pop()
    end,
})



local _aiServer1 = makeLineDrawerForServer(3, 0.05)
g.defineServer("ai_server", "AI Server (Tier 1)", {
    price = 7000,
    getPriceMultiplier = helper.valueGetterNoSelf(0.15, 1),
    computePerSecond = 5000,
    computePreference = {"ai"},
    load = 50,
    heatTolerance = {30, 70},
    heat = 50,
    color = objects.Color("#e37036"),
    draw = function(r)
        local col = gsman.setColor(0, 0, 0)
        local centerR = _aiServer1(r)
        g.drawImageContained("network_intelligence", centerR:get())
        col:pop()
    end,
})


local _aiServer2 = makeLineDrawerForServer(5, 0.05)
g.defineServer("ai_server_t2", "AI Server (Tier 2)", {
    price = 16000,
    getPriceMultiplier = helper.valueGetterNoSelf(0.15, 1),
    computePerSecond = 10000,
    computePreference = {"ai"},
    load = 74,
    heatTolerance = {20, 75},
    heat = 55,
    color = objects.Color("#e37036"),
    draw = function(r)
        local col = gsman.setColor(0, 0, 0)
        local centerR = _aiServer2(r)
        g.drawImageContained("network_intelligence", centerR:get())
        col:pop()
    end,
})

local _aiServer3 = makeLineDrawerForServer(8, 0.04)
g.defineServer("ai_server_t3", "AI Server (Tier 3)", {
    price = 35000,
    getPriceMultiplier = helper.valueGetterNoSelf(0.15, 1),
    computePerSecond = 50000,
    computePreference = {"ai"},
    load = 110,
    heatTolerance = {20, 75},
    heat = 60,
    color = objects.Color("#e37036"),
    draw = function(r)
        local col = gsman.setColor(0, 0, 0)
        local centerR = _aiServer3(r)
        g.drawImageContained("network_intelligence", centerR:get())
        col:pop()
    end,
})
