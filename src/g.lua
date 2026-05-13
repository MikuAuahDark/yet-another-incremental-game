

-- global exports.
-- Gotta go fast, i dont care about "best practice"

local reducers = require("src.modules.reducers")

local Session = require("src.Session")
local Tree = require("src.upgrades.Tree")
local HUD = require("src.ui.hud.hud")



local bgm = require("src.sound.bgm")
local sfx = require("src.sound.sfx")

local simulation = require("src.world.simulation")

---@class g
local g = {}





------------------------
-- Session Management --
------------------------
do
---@type g.Session
local currentSession

local FILENAME = "saves/save1.json"

---@return g.Session
function g.newSession()
    currentSession = Session()
    currentSession.mainWorld:_setupPlaceables()
    return currentSession
end

function g.hasSavedSession()
    return not not love.filesystem.getInfo(FILENAME, "file")
end

---@param path string?
function g.loadSession(path)
    local contents = assert(love.filesystem.read(path or FILENAME))
    local jsondata = json.decode(contents)
    currentSession = Session.deserialize(jsondata)
end

function g.hasSession()
    return not not currentSession
end


---@param prestige integer
---@return g.Tree
function g.loadPrestigeTree(prestige)
    return g.loadTree("prestige_" .. prestige)
end

---@param tree string
---@return g.Tree
function g.loadTree(tree)
    local fname = "assets/prestiges/"..tree..".json"
    local data,er = love.filesystem.read(fname)
    assert(data,er)
    local tabl = assert(json.decode(data))
    return Tree.deserialize(tabl)
end

do
local finalPrestige = 0
for p=0,500 do
    local fname = "assets/prestiges/prestige_" .. tostring(p) .. ".json"
    if not love.filesystem.getInfo(fname) then
        -- welp, we ran out of prestige files!
        break
    end
    finalPrestige = p
end

function g.getFinalPrestige()
    return finalPrestige
end

end


function g.incrementPrestige()
    -- WARNING: this function has FAR REACHING CONSEQUENCES.
    -- will reset upgrades, and do a tonne of other resets.
    local curr = currentSession
    local new = Session()

    local prestige = math.min(g.getFinalPrestige(), curr.prestige + 1)
    new.tree = (g.loadPrestigeTree(prestige))

    -- copy over the important stuff:
    new.prestige = prestige
    new.showTutorials = {
        start = -1,
        upgrades = false
    }

    currentSession = new
end




---@return g.Session
function g.getSn()
    return assert(currentSession, "session not loaded")
end

function g.getWorldTime()
    return currentSession.worldTime
end

---@return g.Tree
function g.getUpgTree()
    return currentSession.tree
end

---@return g.World
function g.getMainWorld()
    return currentSession.mainWorld
end

function g.getPrestige()
    return currentSession.prestige or 0
end

g.isBeingSimulated = simulation.isSimulating

---@param delfile boolean? Delete the save file?
function g.delSession(delfile)
    ---@diagnostic disable-next-line: cast-local-type
    currentSession = nil

    if delfile then
        love.filesystem.remove(FILENAME)
    end
end

function g.saveSession()
    local shouldSave = not (consts.DEV_MODE and love.keyboard.isDown("lshift", "rshift"))
    if shouldSave and not FLAGS.DO_NOT_SAVE then
        log.trace(debug.traceback("Saving session."))
        local data = g.getSn():serialize()
        local contents = json.encode(data)
        assert(love.filesystem.write(FILENAME, contents))
    end
end

function g.saveAndInvalidateSession()
    if not g.hasSession() or g.isBeingSimulated() then return end
    analytics.send("end")

    if not (g.isBeingSimulated() or FLAGS.DO_NOT_SAVE) then
        g.saveSession()
    end
    return g.delSession()
end

end






local sceneManager = require("src.scenes.sceneManager")

---@param scName string
function g.gotoScene(scName)
    sceneManager.gotoScene(scName)
end

---@param scName string
function g.gotoSceneViaMap(scName)
    local _,curName = sceneManager.getCurrentScene()
    assert(curName ~= "map_scene", "Already in map! (this will break stuff.)")
    g.gotoScene("map_scene")
    if scName ~= "map_scene" then
        local mapScene, sceneName = sceneManager.getCurrentScene()
        assert(sceneName == "map_scene")
        mapScene:queueDestinationScene(scName)
    end
end




local definedEvents = objects.Set()

---@param ev string
function g.defineEvent(ev)
    assert(isLoadTime())
    log.trace(string.format("g.defineEvent(%q)", ev))
    definedEvents:add(ev)
end

function g.isEvent(ev)
    return definedEvents:has(ev)
end


function g.assertIsQuestionOrEvent(ev_or_question, level)
    level = level or 0
    local isQuestionOrEvent = (g.getQuestionInfo(ev_or_question) or g.isEvent(ev_or_question))
    if not isQuestionOrEvent then
        error("Invalid question/event: " .. tostring(ev_or_question), 2 + level)
    end
end


---@param ev string
---@param arg1 any
---@param ... unknown
function g.call(ev, arg1, ...)
    -- call systems
    if (type(arg1) == "table") and arg1[ev] then
        arg1[ev](arg1, ...)
    end

    local tree = g.getUpgTree()
    tree:callUpgrades(ev, arg1, ...)

    local sc = sceneManager.getCurrentScene()
    if sc and sc[ev] then
        sc[ev](sc, arg1, ...)
    end
end



local questions = {--[[
    [question] -> {reducer=func, defaultValue=0}
]]}

function g.getQuestionInfo(q)
    return questions[q]
end

---@generic T
---@param question string
---@param reducer fun(a:T, b:T): T
---@param defaultValue T
function g.defineQuestion(question, reducer, defaultValue)
    assert(isLoadTime())
    log.trace(string.format("g.defineQuestion(%q)", question))
    questions[question] = {
        reducer = reducer,
        defaultValue = defaultValue
    }
end


---@param q string
---@param arg1 any
---@param ... any
function g.ask(q, arg1, ...)
    local t = questions[q]
    if not t then
        error("Invalid question "..q)
    end
    local reducer, val = t.reducer, t.defaultValue

    local sc = sceneManager.getCurrentScene()
    if sc and sc[q] then
        val = reducer(val, sc[q](sc, arg1, ...))
    end

    if g.hasSession() then
        local world = g.getMainWorld()
        if world and world[q] then
            val = reducer(val, world[q](world, arg1, ...))
        end
    end

    if (type(arg1) == "table") and arg1[q] then
        val = reducer(val, arg1[q](arg1, ...))
    end

    local tree = g.getUpgTree()

    return tree:askUpgrades(q, val, arg1, ...)
end

---Define 2 questions:
---* `<qname>Modifier` with ADD reducer and default value of `initmodval` (defaults to 0)
---* `<qname>Multiplier` with MULTIPLY reducer and default value of `initmulval` (defaults to 1)
---@param qname string
---@param initmodval number?
---@param initmulval number?
function g.defineProperty(qname, initmodval, initmulval)
    g.defineQuestion(qname .. "Modifier", reducers.ADD, initmodval or 0)
    g.defineQuestion(qname .. "Multiplier", reducers.MULTIPLY, initmulval or 1)
end

---@param qname string
---@param initmodval number?
---@param initmulval number?
---@param ... any
---@return number
function g.getProperty(qname, initmodval, initmulval, ...)
    return (g.ask(qname.."Modifier", ...) + (initmodval or 0)) * (g.ask(qname.."Multiplier", ...) * (initmulval or 1))
end






---@param path string
---@param func fun(path: string)
function g.walkDirectory(path, func)
    local info = love.filesystem.getInfo(path)
    if not info then return end

    if info.type == "file" then
        func(path)
    elseif info.type == "directory" then
        local dirItems = love.filesystem.getDirectoryItems(path)
        for _, pth in ipairs(dirItems) do
            g.walkDirectory(path .. "/" .. pth, func)
        end
    end
end


---@param path string
function g.requireFolder(path)
    local results = {}
    g.walkDirectory(path:gsub("%.", "/"), function(pth)
        if pth:sub(-4,-1) == ".lua" then
            pth = pth:sub(1, -5)
            log.trace("loading file:", pth)
            results[pth] = require(pth:gsub("%/", "."))
        end
    end)
    return results
end




-- g.formatNumber defined here
do
local suffixes = {
    {1e12, "t"},
    {1e9,  "b"},
    {1e6,  "m"},
    {1e3,  "k"}
}

---@param num number
function g.formatNumber(num)
    local isNegative = num < 0
    num = math.abs(num)
    local prefix = (isNegative and "-" or "")

    if num < 1000 then
        if num == math.floor(num) then
            -- is integer!
            return prefix .. ("%d"):format(num)
        elseif num < 1 then
            return prefix .. ("%.2f"):format(num)
        elseif num < 3 then
            return prefix .. ("%.1f"):format(num)
        end
        return prefix .. tostring(math.floor(num))
    end

    for i, suffix in ipairs(suffixes) do
        if num >= suffix[1] then
            local scaled = num / suffix[1]
            local formatted
            if scaled >= 100 then
                formatted = string.format("%.0f", math.floor(scaled))
            elseif scaled >= 10 then
                formatted = string.format("%.14g", math.floor(scaled * 10) / 10)
            else
                formatted = string.format("%.14g", math.floor(scaled * 100) / 100)
            end

            return prefix .. formatted .. suffix[2]
        end
    end
    return prefix .. tostring(num)
end

end







-- fonts:   getBigFont, getSmallFont
do

---@type table<integer, love.Font>
local mainFontCache = {}
local mainFontScaling = 0

-- Tip: For large font file size, it's more memory efficient to load it as `FileData` once and pass it to
-- `love.graphics.newFont` (this is observed when developing Live Simulator: 2 with large font files)
local mainFontFileData = love.filesystem.newFileData("assets/fonts/Tektur-Regular.ttf")
local boldFontFiledata = love.filesystem.newFileData("assets/fonts/Tektur-Bold.ttf")

---@param size integer
function g.getMainFont(size)
    local scaling = love.graphics.getDPIScale() * math.max(ui.getUIScaling(), 1)
    if mainFontScaling ~= scaling then
        mainFontCache = {}
        mainFontScaling = scaling
    end

    if not mainFontCache[size] then
        local f = love.graphics.newFont(mainFontFileData, size, "normal", scaling)
        -- TODO: fallbacks
        mainFontCache[size] = f
    end
    return mainFontCache[size]
end

---@type table<integer, love.Font>
local thickFontCache = {}
local thickFontScaling = 0

---@param size integer
function g.getThickFont(size)
    local scaling = love.graphics.getDPIScale() * math.max(ui.getUIScaling(), 1)
    if thickFontScaling ~= scaling then
        thickFontCache = {}
        thickFontScaling = scaling
    end

    if not thickFontCache[size] then
        local f = love.graphics.newFont(boldFontFiledata, size, "normal", scaling)
        -- TODO: fallbacks
        thickFontCache[size] = f
    end
    return thickFontCache[size]
end

---@deprecated Use `g.getMainFont()` instead
---@param size integer
function g.getBigFont(size)
    return g.getMainFont(size)
end

---@deprecated Use `g.getMainFont()` instead
---@param size integer
function g.getSmallFont(size)
    return g.getMainFont(size)
end

end





-- Images,
-- atlas handling
-- g.drawImage, etc defined here!
do
local nameToQuad = {--[[
    [name] -> Quad
]]}
---@cast nameToQuad table<string, love.Quad>


---@return love.Texture
function g.getAtlas()
    return atlas:getTexture()
end

---@param imageName string
function g.getImageQuad(imageName)
    local quad = nameToQuad[imageName]
    if not quad then
        error("Invalid quad: "..tostring(imageName))
    end
    return quad
end


---@param imageName string|love.Quad
---@param x number
---@param y number
---@param r number?
---@param sx number?
---@param sy number?
---@param kx number?
---@param ky number?
function g.drawImage(imageName, x,y, r,sx,sy,kx,ky)
    return g.drawImageOffset(imageName, x, y, r, sx, sy, 0.5, 0.5, kx, ky)
end

---@param imageName string|love.Quad
---@param x number
---@param y number
---@param r number?
---@param sx number?
---@param sy number?
---@param ox number?
---@param oy number?
---@param kx number?
---@param ky number?
function g.drawImageOffset(imageName, x,y, r, sx,sy, ox,oy, kx,ky)
    local quad
    if type(imageName) == "string" then
        quad = g.getImageQuad(imageName)
    else
        if not (imageName.typeOf and imageName:typeOf("Quad")) then
            error("Expected quad, got: " .. type(imageName) .. " " .. tostring(imageName))
        end
        quad = imageName
    end
    local _,_,w,h = quad:getViewport()
    atlas:draw(quad, x, y, r, sx, sy, (ox or 0.5) * w, (oy or 0.5) * h, kx, ky)
end

---@param imageName string
---@param x number
---@param y number
---@param w number
---@param h number
---@param rot number?
function g.drawImageContained(imageName, x,y, w,h, rot)
    local quad = g.getImageQuad(imageName)
    local _,_,qw,qh = quad:getViewport()
    local scaleX = w / qw
    local scaleY = h / qh
    local scale = math.min(scaleX, scaleY)
    local scaledW = qw * scale
    local scaledH = qh * scale
    local centerX = x + (w - scaledW) / 2
    local centerY = y + (h - scaledH) / 2
    atlas:draw(quad, centerX + scaledW/2, centerY + scaledH/2, rot or 0, scale, scale, qw/2, qh/2)
end


---@param imageName string
function g.isImage(imageName)
    return not not nameToQuad[imageName]
end


local validExtensions = {
    [".png"] = true,
    [".jpg"] = true
}

local function loadImage(path)
    local ext = path:sub(-4):lower()
    if validExtensions[ext] then
        local name = path:match("([^/]+)%.%w+$") -- path/to/foo.png --> "foo"
        local quad = atlas:add(love.image.newImageData(path))
        if nameToQuad[name] then
            error("Duplicate image: "..name)
        end
        nameToQuad[name] = quad
        richtext.defineImage(name, atlas:getTexture(), quad)
    end
end

-- Define 1x1 white image
do
    -- Add padding around to prevent bleeding
    local id = love.image.newImageData(3, 3, "rgba8")
    id:mapPixel(function() return 1, 1, 1, 1 end) -- fill white
    local q = assert(atlas:add(id))
    local x, y = q:getViewport()
    -- Now define it to be 1x1 instead of 3x3
    q:setViewport(x + 1, y + 1, 1, 1, g.getAtlas():getDimensions())
    nameToQuad["1x1"] = q
    nameToQuad["null_image"] = q
end

-- Load other images
g.walkDirectory("src/upgrades", loadImage)
g.walkDirectory("assets/images", loadImage)
g.walkDirectory("src/entities", loadImage)
g.walkDirectory("src/bosses", loadImage)
g.walkDirectory("src/scythes", loadImage)
g.walkDirectory("src/rewards", loadImage)
g.walkDirectory("src/effects", loadImage)
g.walkDirectory("src/cosmetics", loadImage)

-- Set this to true to dump the atlas
if false then
    local atlasImageData = love.graphics.readbackTexture(atlas:getTexture())
    atlasImageData:encode("png", "texture_atlas_dump.png")
end

end



-- metrics are "temporary" values that are set 0 when the game starts.
-- and keep track of arbitrary runtime stuff
-- (eg. number of logs destroyed, seconds-elapsed, mine-count, etc)
local validMetrics = {--[[
    [metricName] -> true
]]}

local metricTc = typecheck.assert("string")

---@param name string
function g.defineMetric(name)
    metricTc(name)

    validMetrics[name] = true
end


local setMetricTc = typecheck.assert("string","number")

---@param name string
---@param x number
function g.setMetric(name, x)
    setMetricTc(name, x)
    assert(validMetrics[name], name)
    g.getSn().metrics[name] = x
end


---@param name string
---@return number
function g.getMetric(name)
    metricTc(name)
    assert(validMetrics[name], name)
    return g.getSn().metrics[name] or 0
end

---@param name string
---@param by number?
function g.incrementMetric(name, by)
    return g.setMetric(name, g.getMetric(name) + (by or 1))
end



local defineStatTc = typecheck.assert("string", "number", "string")

---@type table<string, {addQuestion: string, multQuestion:string, startingValue: number, name: string, rawName: string}>
g.VALID_STATS = {}

---@param id string
---@param startingValue number
---@param name string
---@return number
function g.defineStat(id, startingValue, name)
    defineStatTc(id, startingValue, name)
    assert(not g.VALID_STATS[id], "Redefined stat")
    assert(id:sub(1,1):upper() == id:sub(1,1), "Stats must have first letter capitalized")
    local addQ = "get" .. id .. "Modifier"
    g.defineQuestion(addQ, reducers.ADD, 0)
    local multQ = "get" .. id .. "Multiplier"
    g.defineQuestion(multQ, reducers.MULTIPLY, 1)
    g.VALID_STATS[id]={
        addQuestion = addQ, multQuestion = multQ,
        startingValue = startingValue,
        name = name and loc(name, nil, {context = "This is a statistic, e.g. 'Damage' or 'Health'. Represents a value that can be improved/upgraded."}) or id,
        rawName = name or id
    }
    return 0
end


---@param id string
---@return number
function g.getStatBaseValue(id)
    return g.VALID_STATS[id].startingValue
end



-- stats are recomputed every frame.
-- Think of them as like "global properties".
-- (EG. harvestingSpeed, harvestingDamage)
---@class g.stats
g.stats = {}


-- SSTATS 
-- (if you ever want to quickly search the name of stats, search "sstats")
g.stats.WorldTileSize = g.defineStat("WorldTileSize", 2, "World Size") -- maxed at floor(World.TILE_SIZE / 2)


---@return integer
---@return integer
---@deprecated
function g.getWorldTileDimensions()
    -- the size of dimensions in TILES.
    local sze = g.stats.WorldTileSize
    local wtw = math.floor((sze * 20/20) + 0.5)
    local wth = math.floor((sze * 13/20) + 0.5)
    return wtw, wth
end


---@return number
---@return number
---@deprecated
function g.getWorldDimensions()
    local wtw,wth = g.getWorldTileDimensions()
    local w = math.floor(wtw * consts.WORLD_TILE_SIZE)
    local h = math.floor(wth * consts.WORLD_TILE_SIZE)
    return w, h
end

---@return number
function g.getWorldEdgeLeeway()
    -- Roughly, the distance from world-island-edge to screen-edges
    -- (NOT ENTIRELY ACCURATE; ESTIMATE.)
    return 150
end



---@alias g.ResourceType "money"

-- i wish we could define this as { [g.ResourceType]: number } but it doesnt work that way
---@alias g.Bundle {money?: number}
---@alias g.Resources {money: number}


---@alias g.PrestigeRange {lower: integer, upper: integer}

---@enum (key) g.UpgradeKind
local UPGRADE_KINDS = {
    UNLOCKS=true,
    INVENTORY=true,
    JOB=true,
    EFFICIENCY=true,
    MISC=true
}



---@class g.UpgradeDefinition.ProcGen
---@field weight number The rarity-weight of upgrade
---@field distance [integer,integer] [min,max] distance from root node when generating. A root node has level > 0. E.g. if distance = {1,3}, that means it MUST be between 1 and 3 jumps to a root node.
---@field resource g.ResourceType? The resource (if any) that this upgrade relates to.
---@field needs string? a dependency to another upgrade. Eg: "better_slime" upgrade requires "slime" upgrade as a pre-requisite.
--- this class tells the system: "Hey, this upgrade will be procedurally generated!"
local g_UpgradeDefinition_ProcGen


---@class g.UpgradeDefinition
---@field kind g.UpgradeKind
---@field nameContext string?
---@field frameColor objects.Color? (only for kind == "EFFICIENCY")
---@field targetItem string? (only for kind == "UNLOCKS")
---@field maxLevel integer?
---@field image string?
---@field color objects.Color? (default is white)
---@field priceScaling number?
---@field description string?
---@field descriptionContext string?
---@field rawDescription string?
---@field procGen g.UpgradeDefinition.ProcGen?
---@field getPriceOverride (fun(uinfo:g.UpgradeInfo, level:integer): g.Bundle)?
---@field isHidden (fun(uinfo: g.UpgradeInfo): boolean)?
---@field getValues (fun(uinfo: g.UpgradeInfo, level: integer):number,number?,number?,number?)?
---@field valueFormatter ((string|(fun(x:number):string))[])?
---@field perSecondUpdate (fun(uinfo: g.UpgradeInfo, level: integer, seconds:integer))?
---@field drawUI (fun(uinfo: g.UpgradeInfo, level:integer, r:kirigami.Region))?
local g_UpgradeDefinition = {}



---@class g.UpgradeInfo : g.UpgradeDefinition
---@field type string
---@field name string
---@field maxLevel integer
---@field color objects.Color
---@field description localization.Interpolator?
---@field valueFormatter (string|(fun(x:number):string))[]



---@class g.EffectDefinition
---@field public nameContext string?
---@field public description string?
---@field public descriptionContext string?
---@field public rawDescription string?
---@field public update fun(duration:number, dt:number)?
---@field public image string?
---@field public isDebuff boolean?

---@class g.EffectInfo: g.EffectDefinition
---@field public type string
---@field public name string
---@field public image string
---@field public isDebuff boolean



---@param prestige integer
---@param range g.PrestigeRange|integer
function g.inPrestigeRange(prestige, range)
    if type(range) == "number" then
        return prestige == range
    end
    return (prestige >= range.lower) and (prestige <= range.upper)
end



---@class g._ResourceDefinition
---@field public limitStat string
---@field public image string
---@field public color [number, number, number, number?] Used by resource HUD
---@field public startingLimit number?
---@field public limitStatName string

---@type g.ResourceType[]
g.RESOURCE_LIST = {}

---@type table<string, g._ResourceDefinition>
local RESOURCES = {}


---@param resId string
---@param tabl g._ResourceDefinition
function g.defineResource(resId, tabl)
    RESOURCES[resId] = tabl
    g.defineStat(tabl.limitStat, tabl.startingLimit or 100, tabl.limitStatName)
    table.insert(g.RESOURCE_LIST, resId)
    richtext.defineImage(resId, g.getAtlas(), g.getImageQuad(tabl.image))
end


g.defineResource("money", {
    image="attach_money",
    limitStat="MoneyLimit",
    limitStatName="Money Limit",
    startingLimit=1000,
    color = objects.Color("FFF7D127"),
})



---@param r string
---@return boolean
function g.isValidResource(r)
    return not not RESOURCES[r]
end

---@param resId string
local function assertValidResource(resId)
    if not g.isValidResource(resId) then
        error("invalid resource type: " .. tostring(resId), 2)
    end
end

---@param resId string
function g.isResourceUnlocked(resId)
    assertValidResource(resId)
    return g.getSn().resourceUnlocks[resId]
end

---@param resId string
function g.getResourceInfo(resId)
    assertValidResource(resId)
    return RESOURCES[resId]
end


---@param resId string
---@return number resourcesPerSecond
function g.getResourcesPerSecond(resId)
    assertValidResource(resId)
    -- TODO: Implement when we need it
    -- local world = g.getSn().mainWorld
    -- return world.resourcesPerSecond[resId] or 0
    return 0
end



---@param a g.Bundle
---@param b g.Bundle
---@return g.Resources
function g.addBundles(a,b)
    local result = {}
    for _, resId in ipairs(g.RESOURCE_LIST) do
        result[resId] = (a[resId] or 0) + (b[resId] or 0)
    end
    return result
end


---@param a g.Bundle|number
---@param b g.Bundle|number
---@return g.Resources
function g.multBundles(a,b)
    --[[
    NOTE: this operation is NOT commutative.

    this is to compensate for how qbuses work.
    ]]
    local result = {}

    if type(a) == "number" then
        ---@type g.Bundle
        local temp = {}
        for _, resId in ipairs(g.RESOURCE_LIST) do
            temp[resId] = a
        end
        a = temp
    end

    if type(b) == "number" then
        for _, resId in ipairs(g.RESOURCE_LIST) do
            result[resId] = (a[resId] or 0) * b
        end
    else
        for _, resId in ipairs(g.RESOURCE_LIST) do
            result[resId] = (a[resId] or 0) * (b[resId] or 1)
        end
    end
    return result
end


---@param bundle g.Bundle
---@return g.Bundle
function g.cloneBundle(bundle)
    local result = {}
    for _, resId in ipairs(g.RESOURCE_LIST) do
        result[resId] = bundle[resId] or 0
    end
    return result
end


---@param a g.Bundle
---@param b g.Bundle
---@return g.Resources
function g.minBundle(a, b)
    local result = {}
    for _, resId in ipairs(g.RESOURCE_LIST) do
        local aVal = a[resId] or 0
        local bVal = b[resId] or 0
        result[resId] = math.min(aVal, bVal)
    end
    return result
end

---@param a g.Bundle
---@param b g.Bundle
---@return g.Resources
function g.maxBundle(a, b)
    local result = {}
    for _, resId in ipairs(g.RESOURCE_LIST) do
        local aVal = a[resId] or 0
        local bVal = b[resId] or 0
        result[resId] = math.max(aVal, bVal)
    end
    return result
end

---@param cost g.Bundle The cost of the upgrade
---@param current? g.Bundle The current resources available
---@return number ratio A value between 0 and 1 representing affordability (1 = can fully afford)
function g.getBundleCostRatio(cost, current)
    current = current or g.getResources()

    local totalRatio = 0
    local resourceCount = 0

    for _, resId in ipairs(g.RESOURCE_LIST) do
        local costVal = cost[resId] or 0
        if costVal > 0 then
            resourceCount = resourceCount + 1
            local currentVal = current[resId] or 0
            local ratio = currentVal / costVal
            -- Clamp ratio to [0, 1] so having more than needed doesn't exceed 1
            totalRatio = totalRatio + math.min(ratio, 1)
        end
    end

    -- If no resources required, return 1 (fully affordable)
    if resourceCount == 0 then
        return 1
    end
    return totalRatio / resourceCount
end



---@return g.Resources
function g.getResources()
    return g.getSn().resources
end

---@param resId g.ResourceType
---@return number
function g.getResource(resId)
    assertValidResource(resId)
    return g.getSn().resources[resId]
end

---@param resId g.ResourceType
---@return number
function g.getResourceLimit(resId)
    assertValidResource(resId)
    local info = g.getResourceInfo(resId)
    local limit = assert(g.stats[info.limitStat])
    return limit
end


---@param resId g.ResourceType
function g.addResource(resId, amount)
    assertValidResource(resId)
    local r = g.getSn().resources
    if FLAGS.INFINITE_MONEY then
        amount = math.max(amount, 0)
    end
    r[resId] = math.min(math.max(r[resId] + amount, 0), g.getResourceLimit(resId))
end


---@param bundle g.Bundle
function g.addResources(bundle)
    for resId, amount in pairs(bundle) do
        assertValidResource(resId)
        assert(type(amount) == "number", "?")
        g.addResource(resId, amount)
    end
end


---@param bundle g.Bundle
function g.subtractResources(bundle)
    for resId, amount in pairs(bundle) do
        assertValidResource(resId)
        assert(type(amount) == "number", "?")
        g.addResource(resId, -amount)
    end
end





---@param price g.Bundle
---@param resourcePool g.Bundle?
---@return boolean
function g.canAfford(price, resourcePool)
    if FLAGS.INFINITE_MONEY then
        return true
    end
    local r = resourcePool or g.getSn().resources
    for resId, amount in pairs(price) do
        assertValidResource(resId)
        if amount > (r[resId] or 0) then
            return false
        end
    end
    return true
end




---@param price g.Bundle
---@return boolean
function g.trySubtractResources(price)
    if FLAGS.INFINITE_MONEY then
        return true
    end
    local r = g.getSn().resources
    if not g.canAfford(price) then
        return false
    end

    for resId, amount in pairs(price) do
        r[resId] = r[resId] - amount
    end
    return true
end



--------------------------------------------------
-- Upgrades.
--- 
-- g.getUpgradeInfo(upgradeId)
-- g.getUpgradeLevel(uinfo)
-- g.isUpgradeLocked(uinfo)
-- g.isUpgradeHidden(uinfo)
--------------------------------------------------
do


---@type string[]
g.UPGRADE_LIST = {}

---@type {[string]: g.UpgradeInfo?}
local upgradeInfos = {--[[
    [upgradeId] -> Table (contains all info)
]]}






local function niceAssert(bool, str, val)
    if not bool then
        str = str or "Assertion failed"
        if str and val then
            str = str .. " " .. tostring(val)
        end
        error(str, 2)
    end
end




-- a list of "special" functions that upgrades use,
-- that ARENT q-bus or ev-bus. (eg ignore them)
local SPECIAL_FUNCTIONS = {
    getValues = true,
    isHidden = true,
    getPriceOverride = true,
    drawUI = true,
    getPriceMultiplier = true,
}

g.UPGRADE_INFINITE_LEVEL = 2147483647


---@param id string
---@param name string
---@param def g.UpgradeDefinition
---@return g.UpgradeInfo
function g.defineUpgrade(id, name, def)
    if not (def.kind and UPGRADE_KINDS[def.kind]) then
        error("Invalid upgrade-kind: " .. tostring(def.kind),2)
    end

    ---@cast def g.UpgradeInfo
    def.name = loc(name, nil, {context = def.nameContext})
    assert(not (def.rawDescription and def.description), "raw description and description is mutually exclusive")
    if def.rawDescription then
        def.description = function()
            return def.rawDescription
        end
    elseif def.description then
        local d = def.description --[[@as string]]
        def.description = localization.newInterpolator(d, {context = def.descriptionContext})
    end

    if def.procGen then
        assert(def.procGen.weight > 0, "weight must be positive")
        assert(#def.procGen.distance == 2, "distance must be integer length of 2")
        assert(def.procGen.distance[1] <= def.procGen.distance[2], "invalid distance")
    end

    def.color = def.color or objects.Color.WHITE
    def.valueFormatter = def.valueFormatter or {}
    def.maxLevel = def.maxLevel or consts.DEFAULT_UPGRADE_MAX_LEVEL
    table.insert(g.UPGRADE_LIST, id)

    niceAssert(type(id) == "string")
    if def.image then
        niceAssert(g.isImage(def.image), "Invalid image: ", def.image)
    end

    def.type = id

    assert(not upgradeInfos[id], "Redefined upgrade!")
    upgradeInfos[id] = def

    if rawget(def,"price") then
        error("Deprecated.", 2)
    end

    -- Cache questions and events this upgrade can handle
    for key, func in pairs(def) do
        if type(func) == "function"  then
            local ok = g.getQuestionInfo(key) or g.isEvent(key)
            local ok2 = SPECIAL_FUNCTIONS[key]
            if not (ok or ok2) then
                error("Not a question, event, or special-function: "..tostring(key))
            end
        end
    end

    log.trace(string.format("g.defineUpgrade(%q)", id))
    return def
end


---@param upgradeId string
---@return g.UpgradeInfo
function g.getUpgradeInfo(upgradeId)
    local uinfo = upgradeInfos[upgradeId]
    if not uinfo then
        error("unknown upgrade id '"..upgradeId.."'")
    end
    return uinfo
end


---@param upgradeId string
---@return boolean
function g.isValidUpgrade(upgradeId)
    local uinfo = upgradeInfos[upgradeId]
    return not not uinfo
end



local STAT_UP_COLOR = objects.Color("FFEF8EFC")

---@param uinfo g.UpgradeInfo
---@param level integer
---@param nextLevel boolean? (Display next level values?)
function g.getUpgradeDescription(uinfo, level, nextLevel)
    if not uinfo.description then
        return ""
    end
    local displayValue = {}
    if uinfo.getValues then
        local currentValues = {uinfo:getValues(level)}
        local nextValues = nil
        if nextLevel then
            nextValues = {uinfo:getValues(level + 1)}
            assert(#currentValues == #nextValues)
        end
        for i = 1, #currentValues do
            local formatter = uinfo.valueFormatter[i] or "%.14g"
            local value
            if type(formatter) == "string" then
                value = string.format(formatter, currentValues[i])
                if nextValues then
                    value = value..string.format(helper.wrapRichtextColor(STAT_UP_COLOR, " -> "..formatter), nextValues[i])
                end
            else
                value = formatter(currentValues[i])
                if nextValues then
                    value = value..helper.wrapRichtextColor(STAT_UP_COLOR, " -> "..formatter(nextValues[i]))
                end
            end
            displayValue[tostring(i)] = value
        end
    end
    return uinfo.description(displayValue)
end



end



local drawLockOpen = helper.genDrawUIIntuition("lock_open", "theme", "theme")

---@generic T
---@param id string
---@param name string
---@param shape fun(r:kirigami.Region,col:objects.Color):kirigami.Region
---@param def g._CommonSpecificItemDef<T>
---@param pricemul number?
local function defineItemUpgrades(id, name, shape, def, pricemul)
    pricemul = pricemul or 1
    g.defineUpgrade(id.."_unlock", "Unlock "..name, {
        description = "Unlocks "..name,
        descriptionContext = "Upgrade that unlock an item.",
        kind = "UNLOCKS",
        targetItem = id,
        maxLevel = 1,
        drawUI = function(uinfo, level, r)
            -- Draw server
            local r2 = shape(r:padRatio(0.125), def.color)
            if def.draw then
                def.draw(r2)
            end
            drawLockOpen(uinfo, level, r)
        end,
        isItemUnlocked = function(uinfo, level, iid)
            return iid == id
        end
    })
    g.defineUpgrade(id, name, {
        description = def.description,
        descriptionContext = def.descriptionContext,
        kind = "INVENTORY",
        targetItem = id,
        maxLevel = g.UPGRADE_INFINITE_LEVEL,
        drawUI = function(uinfo, level, r)
            -- Draw server
            local r2 = shape(r:padRatio(0.125), def.color)
            if def.draw then
                def.draw(r2)
            end
        end,
        getItemTotalInventory = function(uinfo, level, iid)
            return iid == id and level or 0
        end
    })
end


----------------------
-- Shape and Colors --
----------------------

do

---@class g.ShapeInfo
---@field public name string
---@field public image string

---@class g._ShapeDef
---@field public name string
---@field public nameContext string?
---@field public image string

---@param def g._ShapeDef
---@return g.ShapeInfo
local function defineShape(def)
    def.name = loc(def.name, nil, {context = def.nameContext})
    def.nameContext = nil
    assert(g.isImage(def.image))
    ---@diagnostic disable-next-line: cast-type-mismatch
    ---@cast def g.ShapeInfo
    return def
end

---@class g.ShapeColorInfo
---@field public name string
---@field public color objects.Color

---@class g._ShapeColorDef
---@field public name string
---@field public nameContext string?
---@field public color objects.Color

---@param def g._ShapeColorDef
---@return g.ShapeColorInfo
local function defineShapeColor(def)
    def.name = loc(def.name, nil, {context = def.nameContext})
    def.nameContext = nil
    def.color = objects.Color(def.color)
    ---@diagnostic disable-next-line: cast-type-mismatch
    ---@cast def g.ShapeColorInfo
    return def
end

---@enum (key) g.Shape
g.SHAPES = {
    triangle = defineShape {name = "Triangle", image = "change_history_fill_20dp"},
    square = defineShape {name = "Square", image = "crop_square_fill_20dp"},
    circle = defineShape {name = "Circle", image = "circle_fill_20dp"},
}

---@enum (key) g.ShapeColor
g.SHAPE_COLORS = {
    white = defineShapeColor {name = "White", color = objects.Color.WHITE},
    yellow = defineShapeColor {name = "Yellow", color = objects.Color("#ebe883")},
    red = defineShapeColor {name = "Red", color = objects.Color("#f16053")},
    blue = defineShapeColor {name = "Blue", color = objects.Color("#12aae6")},
}

---@param shape g.Shape[]
---@param color g.ShapeColor[]
local function randomPickDataShapeAndColor(shape, color)
    local idx = math.floor(love.timer.getTime())
    local hash1 = helper.hashInteger(idx)
    local hash2 = helper.hashInteger((-idx) % 4294967296)
    local targetShape = shape[hash1 % #shape + 1]
    local targetColor = color[hash2 % #color + 1]
    return targetShape, targetColor
end

---Should this be in worldutil or somewhere else?
---@param shape g.Shape[]
---@param color g.ShapeColor[]
function g.getRichtextForShapeAndColor(shape, color)
    local targetShape, targetColor = randomPickDataShapeAndColor(shape, color)
    local shapeInfo = g.SHAPES[targetShape]
    local colorInfo = g.SHAPE_COLORS[targetColor]
    return helper.wrapRichtextColor(colorInfo.color, "{"..shapeInfo.image.."}")
end

end

--------------
-- Machines --
--------------

do

---@alias g.RadiateAlgorithm "taxicab"|"chessboard"

---@type string[]
g.ITEMS = {}

---@type table<string, g.MachineInfo>
local machineInfo = {}

---@class g._AcceptShape
---@field public amount integer
---@field public shape "any"|(g.Shape[])
---@field public color "any"|(g.ShapeColor[])

---@class g._InputSet
---@field public shapes objects.Set<g.Shape>
---@field public colors objects.Set<g.ShapeColor>

---@class g._InputSetWithAmount: g._InputSet
---@field public amount integer

---@param isets g._AcceptShape[]
local function processInputSets(isets)
    -- Process the input sets
    ---@type g._InputSetWithAmount[]
    local outsets = {}
    for _, iset in ipairs(isets) do
        local shapes = iset.shape
        local shapeColors = iset.color

        if shapes == "any" then
            shapes = objects.Set(helper.keys(g.SHAPES))
        else
            ---@cast shapes g.Shape[]
            shapes = objects.Set(shapes)
        end

        if shapeColors == "any" then
            shapeColors = objects.Set(helper.keys(g.SHAPE_COLORS))
        else
            ---@cast shapeColors g.ShapeColor[]
            shapeColors = objects.Set(shapeColors)
        end

        outsets[#outsets+1] = {
            amount = iset.amount,
            shapes = shapes,
            colors = shapeColors,
        }
    end

    return outsets
end

---@class g._MachineDef
---@field public nameContext string?
---@field public description string?
---@field public descriptionContext string?
---@field public tags string[]?
---@field public powerLoad number?
---@field public powerGenerate number?
---@field public input g._AcceptShape[]?
---@field public output g._AcceptShape?
---@field public processTime number? (in seconds)
---@field public wireLength integer? (output only)
---@field public heat number?
---@field public heatTolerance [number, number]?
---@field public heatRadiate integer? (default is 1)
---@field public init fun(inst: g.World.MachineData)?
---@field public onProcessFinished (fun(inst: g.World.MachineData):boolean)?
---@field public onUpdatePowerStage fun(inst: g.World.MachineData, dt: number)? run when `powerLoad`/`powerGenerate` needs update
---@field public onUpdateHeatStage fun(inst: g.World.MachineData, dt: number)? run when `heat` needs update
---@field public onUpdateTileHeatStage fun(inst: g.World.MachineData, dt: number)? run when tile heat needs update
---@field public onUpdate fun(inst: g.World.MachineData, dt: number)? run when most properties needs update
---@field public onDraw fun(inst: g.World.MachineData) (already translated to center of tile)
---@field public onDrawItem fun(r: kirigami.Region) (not translated)
---@field public perSecondUpdate fun(inst: g.World.MachineData, seconds: integer)?

---@class g.MachineInfo: g._MachineDef
---@field public type string
---@field public name string
---@field public tags objects.Set<string>
---@field public powerLoad number
---@field public input g._InputSetWithAmount[]
---@field public output g._InputSetWithAmount?
---@field public processTime number?
---@field public wireLength integer (output only)
---@field public heat number
---@field public heatRadiate integer (always in taxicab distance)

---@param id string
---@param name string
---@param def g._MachineDef
function g.defineMachine(id, name, def)
    assert(not machineInfo[id], "Machine already defined: " .. id)

    ---@type g.MachineInfo
    local info = {
        type = id,
        name = loc(name, nil, {context = def.nameContext}),
        description = nil,
        tags = objects.Set(def.tags),
        powerLoad = def.powerLoad or 0,
        powerGenerate = def.powerGenerate,
        input = processInputSets(def.input or {}),
        output = nil,
        processTime = def.processTime,
        wireLength = def.wireLength or 0,
        heat = def.heat or 0,
        heatRadiate = def.heatRadiate or 1,
        init = def.init,
        onProcessFinished = def.onProcessFinished,
        onUpdate = def.onUpdate,
        onUpdatePowerStage = def.onUpdatePowerStage,
        onUpdateHeatStage = def.onUpdateHeatStage,
        onUpdateTileHeatStage = def.onUpdateTileHeatStage,
        onDraw = def.onDraw,
        onDrawItem = def.onDrawItem,
        perSecondUpdate = def.perSecondUpdate,
    }
    if def.description then
        info.description = loc(def.description, nil, {context = def.descriptionContext})
    end
    if def.output then
        info.output = processInputSets({def.output})[1]
        assert(info.wireLength > 0, "wire length cannot be zero if there's output")
    end
    if def.heatTolerance then
        info.heatTolerance = {
            math.min(def.heatTolerance[1], def.heatTolerance[2]),
            math.max(def.heatTolerance[1], def.heatTolerance[2])
        }
    end

    g.ITEMS[#g.ITEMS+1] = id
    machineInfo[id] = info
end

---@param id string
function g.getMachineInfo(id)
    if not machineInfo[id] then
        error("Machine not found: " .. id)
    end
    return machineInfo[id]
end

---@param itemid string
function g.isMachineUnlocked(itemid)
    if not g.isValidMachine(itemid) then
        error("unknown item id '"..itemid.."'")
    end

    return FLAGS.UNLOCK_ALL_ITEMS or g.ask("isItemUnlocked", itemid)
end

---@param itemid string
function g.isValidMachine(itemid)
    return not not machineInfo[itemid]
end

---@param itemid string
function g.getMachineInventoryCount(itemid)
    assert(g.isValidMachine(itemid))

    if FLAGS.UNLOCK_ALL_ITEMS then
        return 1
    end

    local world = g.getMainWorld()
    local total = world:getItemTotalInventory_NOTABUS(itemid)
    return math.max(total - world.itemCounts[itemid], 0)
end



-- Machine quick helper functions

---@param tags string[]?
---@param append string
local function appendTag(tags, append)
    if tags and helper.index(tags, append) then
        return tags
    end

    local newTags = helper.shallowCopy(tags or {})
    newTags[#newTags+1] = append
    return newTags
end


---@class g._CommonSpecificItemDef<T>
---@field nameContext string?
---@field rawDescription string?
---@field description string?
---@field descriptionContext string?
---@field draw fun(r:kirigami.Region,itemData:T?)?
---@field tags string[]?
---@field color objects.Color
---@field price number
---@field getPriceMultiplier (fun(count:integer):number)?
---@field load number
---@field heat number?
---@field heatTolerance [number, number]?

---@class g._ServerDef: g._CommonSpecificItemDef<g.World.MachineData>
---@field emitShape [g.Shape, g.ShapeColor]
---@field duration number

---@param id string
---@param name string
---@param def g._ServerDef
function g.defineServer(id, name, def)
    defineItemUpgrades(id, name, worldutil.drawServerShape, def)
    g.defineMachine(id, name, {
        nameContext = def.nameContext,
        description = def.description,
        descriptionContext = def.descriptionContext,
        powerLoad = def.load,
        tags = appendTag(def.tags, "server"),
        heat = def.heat,
        heatTolerance = def.heatTolerance,
        processTime = def.duration,

        onProcessFinished = function(inst)
            -- TODO: Emit single shape with specific color
            return true
        end,
        onDraw = function(itemData)
            local wtz = consts.WORLD_TILE_SIZE * 0.75
            local r = Kirigami(-wtz / 2, -wtz / 2, wtz, wtz)
            local r2 = worldutil.drawServerShape(r, def.color)
            if def.draw then
                def.draw(r2, itemData)
            end
        end,
        onDrawItem = function(r)
            local r2 = worldutil.drawServerShape(r, def.color)
            if def.draw then
                def.draw(r2)
            end
        end
    })
end



---@class g._DataRewardProcDef: g._CommonSpecificItemDef<g.World.MachineData>
---@field inputs [integer, g.Shape|"any", g.ShapeColor|"any"][] amount, shape, color
---@field rewards g.Bundle
---@field duration number

---@param id string
---@param name string
---@param def g._DataRewardProcDef
function g.defineDataRewardProcessor(id, name, def)
    defineItemUpgrades(id, name, worldutil.drawDataOutShape, def)

    assert(#def.inputs > 0, "need at least 1 input")
    ---@type g._AcceptShape[]
    local newInputs = {}
    for _, v in ipairs(def.inputs) do
        newInputs[#newInputs+1] = {
            amount = v[1],
            shape = v[2] == "any" and "any" or {v[2]},
            color = v[3] == "any" and "any" or {v[3]},
        }
    end

    return g.defineMachine(id, name, {
        nameContext = def.nameContext,
        description = def.description,
        descriptionContext = def.descriptionContext,
        powerLoad = def.load,
        tags = appendTag(def.tags, "data"),
        heat = def.heat,
        heatTolerance = def.heatTolerance,
        processTime = def.duration,
        inputs = newInputs,

        onProcessFinished = function(inst)
            -- TODO: More sophisticated (e.g. effects, buses)
            g.addResources(def.rewards)
            return true
        end,
        onDraw = function(inst)
            local wtz = consts.WORLD_TILE_SIZE * 0.75
            local r = Kirigami(-wtz / 2, -wtz / 2, wtz, wtz)
            local r2 = worldutil.drawServerShape(r, def.color)
            if def.draw then
                def.draw(r2, inst)
            end
        end,
        onDrawItem = function(r)
            local r2 = worldutil.drawServerShape(r, def.color)
            if def.draw then
                def.draw(r2)
            end
        end
    })
end

---@class g._DataTransformerDef: g._CommonSpecificItemDef<g.World.MachineData>
---@field inputs [integer, g.Shape|"any", g.ShapeColor|"any"][] amount, shape, color
---@field output [integer, g.Shape, g.ShapeColor] amount, shape, color
---@field duration number

---@param id string
---@param name string
---@param def g._DataTransformerDef
function g.defineDataTransformer(id, name, def)
    defineItemUpgrades(id, name, worldutil.drawDataInShape, def)
    assert(#def.inputs > 0, "use g.defineServer instead")
    ---@type g._AcceptShape[]
    local newInputs = {}
    for _, v in ipairs(def.inputs) do
        newInputs[#newInputs+1] = {
            amount = v[1],
            shape = v[2] == "any" and "any" or {v[2]},
            color = v[3] == "any" and "any" or {v[3]},
        }
    end

    return g.defineMachine(id, name, {
        nameContext = def.nameContext,
        description = def.description,
        descriptionContext = def.descriptionContext,
        powerLoad = def.load,
        tags = appendTag(def.tags, "transform"),
        heat = def.heat,
        heatTolerance = def.heatTolerance,
        processTime = def.duration,
        inputs = def.inputs,
        output = {
            amount = def.output[1],
            shape = {def.output[2]},
            color = {def.output[3]},
        },

        onProcessFinished = function(inst)
            -- TODO: Emit shape with specific color
            return true
        end,
        onDraw = function(inst)
            local wtz = consts.WORLD_TILE_SIZE * 0.75
            local r = Kirigami(-wtz / 2, -wtz / 2, wtz, wtz)
            local r2 = worldutil.drawServerShape(r, def.color)
            if def.draw then
                def.draw(r2, inst)
            end
        end,
        onDrawItem = function(r)
            local r2 = worldutil.drawServerShape(r, def.color)
            if def.draw then
                def.draw(r2)
            end
        end
    })
end


---@class g._PowerGenDef: g._CommonSpecificItemDef<g.World.GeneratorData>
---@field power number
---@field wireLength integer
---@field fuel [integer, g.Shape|"any", g.ShapeColor|"any"][]? amount, shape, color
---@field fuelProcessDuration number?
---@field powerDuration number?

---@param id string
---@param name string
---@param def g._PowerGenDef
function g.definePowerGenerator(id, name, def)
    defineItemUpgrades(id, name, worldutil.drawPowerGenShape, def)

    ---@type g._AcceptShape[]?
    local newInputs = nil
    if def.fuel then
        assert(def.powerDuration and def.powerDuration > 0, "need generation duration")
        assert(def.fuelProcessDuration and def.fuelProcessDuration > 0, "need fuel process duration")
        for _, v in ipairs(def.fuel) do
            newInputs[#newInputs+1] = {
                amount = v[1],
                shape = v[2] == "any" and "any" or {v[2]},
                color = v[3] == "any" and "any" or {v[3]},
            }
        end
    end

    return g.defineMachine(id, name, {
        name = name,
        nameContext = def.nameContext,
        rawDescription = def.rawDescription,
        description = def.description,
        descriptionContext = def.descriptionContext,
        tags = appendTag(def.tags, "powergen"),
        price = def.price,
        getPriceMultiplier = def.getPriceMultiplier,
        powerLoad = 0,
        powerGenerate = def.power,
        wireLength = def.wireLength,
        input = newInputs,
        processTime = def.fuelProcessDuration or 0,

        init = function(inst)
            ---@cast inst g.World.GeneratorData
            inst.duration = def.powerDuration or 0
            inst.timeout = 0
        end,
        onProcessFinished = function(inst)
            ---@cast inst g.World.GeneratorData
            inst.timeout = inst.duration
            return true
        end,
        onUpdatePowerStage = function(inst, dt)
            ---@cast inst g.World.GeneratorData
            inst.timeout = math.max(inst.timeout - dt, 0)
            if inst.timeout > 0 or inst.duration == 0 then
                inst.powerGenerate = def.power
            else
                inst.powerGenerate = 0
            end
        end,
        onDraw = function(inst)
            local wtz = consts.WORLD_TILE_SIZE * 0.75
            local r = Kirigami(-wtz / 2, -wtz / 2, wtz, wtz)
            local r2 = worldutil.drawPowerGenShape(r, def.color)
            if def.draw then
                ---@cast inst g.World.GeneratorData
                def.draw(r2, inst)
            end
        end,
        onDrawItem = function(r)
            local r2 = worldutil.drawPowerGenShape(r, def.color)
            if def.draw then
                def.draw(r2)
            end
        end
    })
end

---@class g._PowerRelayDef: g._CommonSpecificItemDef<g.World.MachineData>
---@field wireLength integer

---@param id string
---@param name string
---@param def g._PowerRelayDef
function g.definePowerRelay(id, name, def)
    defineItemUpgrades(id, name, worldutil.drawPowerRelayShape, def, 0.5)

    return g.defineMachine(id, name, {
        nameContext = def.nameContext,
        description = def.description,
        descriptionContext = def.descriptionContext,
        powerLoad = 0,
        powerGenerate = 0,
        input = {
            {
                amount = 1,
                shape = "any",
                color = "any"
            }
        },
        output = {
            amount = 1,
            shape = "any",
            color = "any"
        },
        wireLength = def.wireLength,
        tags = appendTag(def.tags, "powerrelay"),
        heat = def.heat,
        heatTolerance = def.heatTolerance,
        processTime = 0,

        onProcessFinished = function (inst)
            -- TODO: Emit shape with specific color
            return true
        end,
        onUpdate = function(inst)
            -- TODO: Query the first input and change output accordingly
        end,
        onDraw = function(inst)
            local wtz = consts.WORLD_TILE_SIZE * 0.75
            local r = Kirigami(-wtz / 2, -wtz / 2, wtz, wtz)
            local r2 = worldutil.drawPowerRelayShape(r, def.color)
            if def.draw then
                def.draw(r2, inst)
            end
        end,
        onDrawItem = function(r)
            local r2 = worldutil.drawPowerRelayShape(r, def.color)
            if def.draw then
                def.draw(r2)
            end
        end
    })

    -- return g.defineItem(id, {
    --     category = "powerrelay",
    --     name = name,
    --     nameContext = def.nameContext,
    --     rawDescription = def.rawDescription,
    --     description = def.description,
    --     descriptionContext = def.descriptionContext,
    --     tags = def.tags,
    --     price = def.price,
    --     getPriceMultiplier = def.getPriceMultiplier,
    --     load = 0,
    --     wireLength = def.wireLength,
    --     draw = function(itemData)
    --         ---@cast itemData g.World.PowerData
    --         local wtz = consts.WORLD_TILE_SIZE * 0.75
    --         local r = Kirigami(-wtz / 2, -wtz / 2, wtz, wtz)
    --         local r2 = worldutil.drawPowerRelayShape(r, def.color)
    --         if def.draw then
    --             def.draw(r2, itemData)
    --         end
    --     end,
    --     drawItem = function(r)
    --         local r2 = worldutil.drawPowerRelayShape(r, def.color)
    --         if def.draw then
    --             def.draw(r2)
    --         end
    --     end
    -- })
end

end



----------------------
-- Placement And Stuff
----------------------

---@param tx integer
---@param ty integer
function g.canPutItem(tx, ty)
    return g.getMainWorld():canPutItem(tx, ty)
end

---@param itemId string
---@param tx integer
---@param ty integer
function g.putItem(itemId, tx, ty)
    return g.getMainWorld():putItem(itemId, tx, ty)
end

---@param tx integer
---@param ty integer
function g.getItem(tx, ty)
    local world = g.getMainWorld()

    if world.items:contains(tx, ty) then
        return world.items:get(tx, ty)
    end

    return nil
end

---@param item g.World.MachineData
---@return boolean
---@diagnostic disable-next-line: duplicate-set-field, missing-return
function g.removeItem(item) end

---@param tx integer
---@param ty integer
---@diagnostic disable-next-line: duplicate-set-field
function g.removeItem(tx, ty)
    local world = g.getMainWorld()
    local item = nil
    if type(tx) == "table" then
        item = tx --[[@as g.World.MachineData]]
        tx, ty = item.tileX, item.tileY

        local it = world.items:get(tx, ty)
        if not it == item then
            log.error("item "..tostring(item).." retrieved but world pos ("..tx..","..ty..") has different item "..tostring(it))
            if consts.DEV_MODE then
                error("position source of truth violation")
            end
        end
    else
        item = world.items:get(tx, ty)
    end

    local ok = false
    if item then
        -- Remove connections
        local wos = world.wireOutput[item] or {}
        if #wos > 0 then
            for i = #wos, 1, -1 do
                local wire = wos[i]
                world:_disconnectWire(wire)
            end
        end

        local wis = world.wireInput[item] or {}
        if #wis > 0 then
            for i = #wis, 1, -1 do
                local wire = wis[i]
                world:_disconnectWire(wire)
            end
        end

        item.removed = true
        ok = true
    end
    world.items:set(tx, ty, nil)
    return ok
end

---@param wire g.World.Wire2
local function logErrorWire(wire)
    log.error("wire info; from="..tostring(wire.from).."; to="..tostring(wire.to))
end

---@param output g.World.MachineData
---@param input g.World.MachineData
function g.disconnectWire(output, input)
    local world = g.getMainWorld()
    ---@type g.World.Wire2?
    local targetWireOut = nil
    for _, wire in ipairs(world.wireOutput[output] or {}) do
        if wire.to == input then
            targetWireOut = wire
            break
        end
    end

    ---@type g.World.Wire2?
    local targetWireIn = nil
    for _, wire in ipairs(world.wireInput[input] or {}) do
        if wire.from == output then
            targetWireIn = wire
            break
        end
    end

    if targetWireOut ~= targetWireIn then
        log.error("source of truth violation on wires")
        log.error("target output wire is: "..tostring(targetWireOut))
        if targetWireOut then
            logErrorWire(targetWireOut)
        end
        log.error("target input wire is: "..tostring(targetWireIn))
        if targetWireIn then
            logErrorWire(targetWireIn)
        end
        if consts.DEV_MODE then
            error("source of truth violation on wires")
        else
            return false
        end
    end

    if targetWireOut and targetWireIn then
        assert(targetWireOut == targetWireIn, "???")
        world:_disconnectWire(targetWireOut)
        return true
    end

    return false
end

---@param output g.World.MachineData source
---@param input g.World.MachineData destination
function g.canConnectWire(output, input)
    local outinfo = g.getMachineInfo(output.type)
    local ininfo = g.getMachineInfo(input.type)

    if not output.output then
        -- No output. Can't connect.
        return false
    end

    if #input.input == 0 then
        -- No input. Can't connect.
        return false
    end

    local wireLength = math.max(outinfo.wireLength, ininfo.wireLength)
    if worldutil.getDistance("chessboard", output.tileX - input.tileX, output.tileY - input.tileY) > wireLength then
        -- Too far
        return false
    end

    -- Check input compatibility
    local outshape = objects.Set(output.output.shapes)
    local outcolor = objects.Set(output.output.colors)
    for _, iset in ipairs(input.input) do
        outshape = outshape:filter(function(item)
            return not iset.shapes:contains(item)
        end)
        outcolor = outcolor:filter(function(item)
            return not iset.colors:contains(item)
        end)

        if outshape:length() == 0 and outcolor:length() == 0 then
            break
        end
    end
    if outshape:length() > 0 or outcolor:length() > 0 then
        -- Not all inputs can accept the output type
        return false
    end

    -- Input satisfied
    return true
end

---@param output g.World.MachineData source
---@param input g.World.MachineData destination
function g.connectWire(output, input)
    if not g.canConnectWire(output, input) then
        -- Not connectable
        return false
    end

    local world = g.getMainWorld()
    if world.wireOutput[output] then
        for _, wire in ipairs(world.wireOutput[output]) do
            if wire.to == input then
                -- Already connected
                return false
            end
        end
    end

    ---@type g.World.Wire2
    local wire = {
        from = output,
        to = input,
        criterion = {
            shapes = output.output.shapes,
            colors = output.output.colors,
        },
        shapes = {},
        colors = {},
        positions = {},
    }

    if not world.wireOutput[output] then
        world.wireOutput[output] = {}
    end
    table.insert(world.wireOutput[output], wire)

    if not world.wireInput[input] then
        world.wireInput[input] = {}
    end
    table.insert(world.wireInput[input], wire)

    return true
end

---@param tx integer
---@param ty integer
---@return number
function g.getTileHeat(tx, ty)
    local world = g.getMainWorld()
    assert(world.heat:contains(tx, ty), "out of range")
    return world.heat:get(tx, ty) or 0
end


----------------
-- Item Problems
----------------

do

---@enum (key) g.ItemProblems
local ITEM_PROBLEMS = {
    -- Server is not connected to datacenter.
    not_connected = {
        error = true,
        icon = "power_off",
        text = loc("Not connected to data output!", nil, {
            context = "Think of it as connection between machines."}),
    },
    -- No suitable data input found
    no_input_connection = {
        error = true,
        icon = "power_off",
        text = loc("Not connected to data input!", nil, {
            context = "Think of it as connection between machines."}),
    },
    -- Server is not connected to data input and output
    no_io_connection = {
        error = true,
        icon = "power_off",
        text = loc("Not connected to data input and output!", nil, {
            context = "Think of it as connection between machines."}),
    },
    -- Datacenter load is too high.
    overloaded = {
        error = false,
        icon = "bolt",
        text = loc("Power network load exceeded!", nil, {
            context = "Think of \"load\" as the \"electricity load\""}),
    },
    -- Not connected to power network
    no_power = {
        error = true,
        icon = "bolt",
        text = loc("Not connected to power network!", nil, {
            context = "Think of it as connection between the machine and the power grid."}),
    },
    -- Server is too hot
    overheat = {
        error = false,
        icon = "emergency_heat",
        text = loc("Heat tolerance exceeded!", nil, {
            context = "Denotes when a machine is overheating."}),
    },
    -- Data output is not connected to any server.
    no_connection = {
        error = false,
        icon = "power_off",
        text = loc("Not connected to any server!", nil, {
            context = "Think of it as connection between machines."})
    },
    -- Booster does not provide any benefit
    booster_noop = {
        error = false,
        icon = "warning",
        text = loc("Booster is doing nothing!", nil, {
            context = "Booster is an item that boosts stats of other machines."})
    },
    -- Data input is not connected to any server
    input_not_connected = {
        error = false,
        icon = "power_off",
        text = loc("Not connected to any server!", nil, {
            context = "Think of it as connection between machines."})
    },
    -- Data output is overloaded
    data_bottleneck = {
        error = true,
        icon = "database",
        text = loc("No suitable data output found for the current data load!", nil, {
            context = "The server cannot emit data because all the wires are occupied."}),
    }
}

---@param a g.ItemProblems
---@param b g.ItemProblems
local function sortMachineProblems(a, b)
    local ai = ITEM_PROBLEMS[a]
    local bi = ITEM_PROBLEMS[b]
    -- Make sure "Error" one is first
    if ai.error ~= bi.error then
        return ai.error
    end
    return a < b
end

---@param machine g.World.MachineData
---@deprecated use g.getMachineProblems instead
function g.getItemProblems(machine)
    return g.getMachineProblems(machine)
end

---@param machine g.World.MachineData
function g.getMachineProblems(machine)
    local r = machine.problems:totable()
    table.sort(r, sortMachineProblems)
    return r
end

---@param problem g.ItemProblems
function g.getItemProblemInfo(problem)
    return (assert(ITEM_PROBLEMS[problem]))
end

end



-------------------
-- ENTITY FUNCTIONS
-------------------
do

---@class g.Entity
---@field type string
---@field x number
---@field y number
---@field id integer
---@field boundingBox [number,number,number,number]? (x,y,w,h; must be set on `Entity:init()`!)
---@field shadow (false|"shadow_medium"|"shadow_small"|"shadow_big")?
---@field sx number?
---@field sy number?
---@field ox number?
---@field oy number?
---@field rot number?
---@field alpha number?
---@field orbitRing integer?
---@field bulgeAnimation {time: number, magnitude: number, duration:number}?
---@field image string?
---@field drawOrder number?
---@field lifetime number?
---@field blendmode love.BlendMode?
---@field blendalphamode love.BlendAlphaMode?
---@field init (fun(ent:g.Entity,...:any))?
---@field update (fun(ent: g.Entity, dt:number))?
---@field perSecondUpdate (fun(e:g.Entity, seconds:integer))?
---@field drawBelow (fun(ent: g.Entity))?
---@field draw (fun(ent: g.Entity))?
local Entity = {}

---@type table<string, table>
local ENTITY_DEFS = {}
---@type table<table, true|nil>
local REVERSE_ENTITY_MT = {}

---@param type string
---@param etype g.Entity|{x:nil,y:nil,type:nil}
function g.defineEntity(type, etype)
    -- TODO, assertions maybe?
    assert(etype.x == nil, "x is reserved field")
    assert(etype.y == nil, "y is reserved field")
    assert(etype.type == nil, "type is reserved field")
    etype.type = type
    local mt = {__index=etype}
    ENTITY_DEFS[type] = mt
    REVERSE_ENTITY_MT[mt] = true
end


local currentId = 0

---@param ename string
---@param x number
---@param y number
---@return g.Entity
function g.spawnEntity(ename, x,y, ...)
    local w = g.getMainWorld()
    local mt = ENTITY_DEFS[ename]
    if not mt then
        error("Invalid entity type: " .. tostring(ename))
    end

    ---@type g.Entity
    local ent = setmetatable({
        id = currentId,
        x=x,y=y, type=ename
    }, mt)

    if ent.init then
        ent:init(...)
    end

    currentId = currentId + 1
    assert(type(ent) == "table")
    assert(ent.type)
    w.entities:addBuffered(ent)
    return ent
end


---@param ent g.Entity
---@param duration number
---@param magnitude number
function g.bulgeEntity(ent, duration, magnitude)
    ent.bulgeAnimation = {
        duration = duration,
        time = duration,
        magnitude = magnitude
    }
end


function g.isEntity(obj)
    local mt = getmetatable(obj)
    return not not REVERSE_ENTITY_MT[mt]
end


function g.removeEntity(ent)
    local w = g.getMainWorld()
    w.entities:removeBuffered(ent)
end


end


local hud = HUD()

function g.getHUD()
    return hud
end



-- g.playWorldSound
-- g.playUISound
do

----------
-- SFXs --
----------

---@param soundname string
---@param pitch number? (defaults to 1)
---@param volume number? (defaults to 1)
---@param pitchVar number? (pitch variance, default 0)
---@param volumeVar number? (volume variance, default 0)
function g.playWorldSound(soundname, pitch, volume, pitchVar, volumeVar)
    if love.audio.getActiveSourceCount() > consts.MAX_PLAYING_SOURCES then
        return false
    end
    if select(2, sceneManager.getCurrentScene()) == "harvest_scene" then
        return sfx.play(soundname, pitch, volume, pitchVar, volumeVar)
    end
    return false
end


---@param soundname string
---@param pitch number? (defaults to 1)
---@param volume number? (defaults to 1)
---@param pitchVar number? (pitch variance, default 0)
---@param volumeVar number? (volume variance, default 0)
function g.playUISound(soundname, pitch, volume, pitchVar, volumeVar)
    return sfx.play(soundname, pitch, volume, pitchVar, volumeVar)
end





local validExtensions = {
    wav = true,
    mp3 = true,
    ogg = true,
    flac = true
}

---@param path string
local function loadSound(path)
    local pathrev = path:reverse()
    local ext = pathrev:sub(1, (pathrev:find(".", 1, true) or 1) - 1):reverse():lower()

    if validExtensions[ext] then
        local basename = pathrev:sub(1, pathrev:find("/", 1, true)-1):reverse()

        if #basename > 0 then
            local name = basename:sub(1, -#ext - 2)
            if name:sub(1,1) ~= "_" then
                sfx.defineSound(name, path)
            end
        end
    end
end

g.walkDirectory("assets/sfx", loadSound)


----------
-- BGMs --
----------

-- Higher number means higher priority.
g.BGMID = {
    -- TITLE = 999, -- Title and settings
    -- MAP = 1, -- Map scene
    -- HARVEST = 2, -- Harvest scene
    -- UPGRADE = 3, -- Upgrade scene
    -- CUSTOMIZATION = 4, -- Customization scene
    -- BOSS = 100, -- Boss theme
}


---@param path string
---@param prio integer
---@param isAmbient boolean?
local function registerBGMFromDirectories(path, prio, isAmbient)
    ---@type string[]
    local files = {}

    g.walkDirectory(path, function(filename)
        local pathrev = filename:reverse()
        local ext = pathrev:sub(1, (pathrev:find(".", 1, true) or 1) - 1):reverse():lower()

        if validExtensions[ext] then
            local basename = pathrev:sub(1, pathrev:find("/", 1, true)-1):reverse()

            if #basename > 0 then
                local name = basename:sub(1, -#ext - 2)
                if name:sub(1,1) ~= "_" then
                    files[#files+1] = filename
                end
            end
        end
    end)

    if #files == 0 then
        error("no bgm files in "..path)
    end

    return bgm.register(prio, files, isAmbient)
end

-- We cannot use g.walkDirectory because we need all the files first then register
-- the BGM in one go using `bgm.register`.
-- registerBGMFromDirectories("assets/bgm/boss", g.BGMID.BOSS, false)
-- registerBGMFromDirectories("assets/bgm/customization", g.BGMID.CUSTOMIZATION, true)
-- registerBGMFromDirectories("assets/bgm/harvest", g.BGMID.HARVEST, true)
-- registerBGMFromDirectories("assets/bgm/map", g.BGMID.MAP, true)
-- registerBGMFromDirectories("assets/bgm/title", g.BGMID.TITLE, true)
-- registerBGMFromDirectories("assets/bgm/upgrades", g.BGMID.UPGRADE, true)


---Request playing specific BGM ID
---@param id integer BGM ID. Use `g.BGMID` for the fixed constants.
function g.requestBGM(id)
    return bgm.request(id)
end


end



---@param particleName string
---@param x number
---@param y number
---@param amount integer?
function g.spawnParticle(particleName, x, y, amount)
    if g.isBeingSimulated() then return end
    return g.getMainWorld().particles:spawnParticles(particleName, x, y, amount)
end



---@return "dark"|"light"
function g.getSystemTheme()
    -- FIXME: Update my LOVE 12 API so I don't need line below
    ---@diagnostic disable-next-line: undefined-field
    local t = love.window.getSystemTheme()
    if t == "unknown" then t = "light" end
    return t
end



g.COLORS = {

    BUTTON_FADE_1 = objects.Color("FF9F14F6"),
    BUTTON_FADE_2 = objects.Color("FF3B12A4"),

    UPGRADE_KINDS = {
        UNLOCKS = objects.Color("#43b4e8"),
        INVENTORY = objects.Color("FF6F43E8"),
        JOB = objects.Color("#61d4b1"),
        MISC = objects.Color("#c4d14d"),
        FALLBACK = objects.Color.WHITE,
    },

    CANT_AFFORD = objects.Color("FFD72D2D"),
    CAN_AFFORD = objects.Color("FF73FF73"),

    MONEY = objects.Color("FFF7D127"),
    RECOMMENDED = objects.Color("FF9DEC4E"),
    UPGRADE_CONNECTOR = objects.Color("FF000000"),

    UI = {
        -- Key matches g.getSystemTheme output.
        MAIN = {
            dark = {
                PRIMARY = objects.Color.BLACK,
                PRIMARY_INVERT = objects.Color.WHITE,
                PANEL = objects.Color("FF222222"),
                CARD = objects.Color("FF101010"),
                TEXT = objects.Color.WHITE,
                TAB_INACTIVE = objects.Color("FF404040"),
                WORLD_BACKGROUND = objects.Color("#333333"),
            },
            light = {
                PRIMARY = objects.Color.WHITE,
                PRIMARY_INVERT = objects.Color.BLACK,
                PANEL = objects.Color("#eeeeee"),
                CARD = objects.Color.WHITE,
                TEXT = objects.Color.BLACK,
                TAB_INACTIVE = objects.Color("FFB0B0B0"),
                WORLD_BACKGROUND = objects.Color("#eeeeee"),
            }
        },
        BORDER = objects.Color("FF979797"),
        DEBUFF = objects.Color("FFE85A5A"),
        BUFF = objects.Color("FF57DB6F"),
        OVERCLOCKED = objects.Color("FF3FB5EC"),
        WARNING = objects.Color("FFE6C562"),

        TEXT_POWER_RELATED = objects.Color("#abeeff"),
        TEXT_CPS = objects.Color("#e0fcae"),
        TEXT_DPS = objects.Color("#fcdeae")
    },

    TILE_HOT = objects.Color("7fD63900"),
    TILE_COLD = objects.Color("7fabeeff"),

    -- FIXME: Register the color in `g.defineJobCategory`?
    JOBS = {
        GENERAL = g.getJobCategoryInfo("general").color,
        VIDEO = g.getJobCategoryInfo("video").color,
        AI = g.getJobCategoryInfo("ai").color,
    },
}

do
---@param tag string
---@param color objects.Color
local function defineColorTag(tag, color)
    richtext.defineEffect(tag, function(args, x,y, context, next)
        local col = gsman.setColor(color)
        next(context.textOrDrawable, x,y)
        col:pop()
    end)
end
---@param prefix string
local function registerColor(tab, prefix)
    for k, v in pairs(tab) do
        if getmetatable(v) == objects.Color then
            defineColorTag(prefix..tostring(k), v)
        elseif type(v) == "table" then
            registerColor(v, prefix..tostring(k).."_")
        end
    end
end
registerColor(g.COLORS, "COLORS_")
end


return g
