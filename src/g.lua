

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
    new.showTutorials = {harvest=false, upgrades=false}

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
-- g.defineQuestion("getJobFrequencyModifier", reducers.ADD, 0) -- arguments: g.JobCategory
g.stats.MaxLoad = g.defineStat("MaxLoad", 10, "Max Load")
g.stats.JobFrequency = g.defineStat("JobFrequency", 0, "Job Spawn Frequency")
-- World stat
g.stats.WorldTileSize = g.defineStat("WorldTileSize", 2, "World Size") -- maxed at floor(World.TILE_SIZE / 2)


---@return integer
---@return integer
function g.getWorldTileDimensions()
    -- the size of dimensions in TILES.
    local sze = g.stats.WorldTileSize
    local wtw = math.floor((sze * 20/20) + 0.5)
    local wth = math.floor((sze * 13/20) + 0.5)
    return wtw, wth
end


---@return number
---@return number
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

---------------------
-- Compute Jobs
---------------------

do

---Key is the ID, value is the name
---@type table<string, [string,string]>
g.VALID_JOB_CATEGORIES = {}
---@type g.JobCategory[]
g.JOB_CATEGORIES = {}

---@class g.Job
---@field public type string
---@field public name string
---@field public category g.JobCategory
---@field public computePower number
---@field public outputData number
---@field public resource g.Bundle
---@field public timeout number If not taken for this seconds, remove from queue.

---@param id string
---@param name string
---@param def {nameContext:string?,startingStatValue:number}
function g.defineJobCategory(id, name, def)
    assert(not g.VALID_JOB_CATEGORIES[id], "Redefined job category!")
    local ctx = def.nameContext
    if not ctx then ctx = nil end
    g.JOB_CATEGORIES[#g.JOB_CATEGORIES+1] = id
    g.VALID_JOB_CATEGORIES[id] = {name, loc(name, nil, {context = ctx})}
    return g.defineStat(name.."JobFrequency", def.startingStatValue, name.." Job Spawn Frequency")
end

---@param jobCategory g.JobCategory
---@param raw boolean?
---@return string
function g.getJobCategoryName(jobCategory, raw)
    local info = g.VALID_JOB_CATEGORIES[jobCategory]
    if not info then
        error("unknown job category '"..jobCategory.."'")
    end
    return info[raw and 2 or 1]
end

---@alias g.JobCategory
---General job
---| "general"
---Video processing job
---| "video"
---AI-related job
---| "ai"
g.stats.GeneralJobFrequency = g.defineJobCategory("general", "General", {
    startingStatValue = 0.1,
    nameContext = "General computer processing job"})
g.stats.VideoJobFrequency = g.defineJobCategory("video", "Video", {
    startingStatValue = 0,
    nameContext = "Video processing job for computer (e.g. transcoding)"})
g.stats.AIJobFrequency = g.defineJobCategory("ai", "AI", {
    startingStatValue = 0,
    nameContext = "AI processing job for computer (e.g. inferencing or training)"})

end



-------------
-- Job System
-------------
do

---@type table<string, g.JobInfo>
g.VALID_JOBS = {}

---@class g.JobInfo
---@field public id string
---@field public name string
---@field public category g.JobCategory
---@field public compute [integer,integer] -- min, max
---@field public data [integer,integer] -- min, max
---@field public money [integer,integer] -- min, max

---@class g.JobDef
---@field package compute [integer,integer]|integer -- min, max
---@field package data [integer,integer]|integer -- min, max
---@field package money [integer,integer]|integer -- min, max

---@param id string
---@param name string
---@param category g.JobCategory
---@param def g.JobDef
function g.defineJob(id, name, category, def)
    if g.VALID_JOBS[id] then
        error("job '"..id.."' already defined")
    end
    g.getJobCategoryName(category) -- for assertion

    local dc, dd, dm
    if type(def.compute) == "number" then
        dc = {def.compute, def.compute}
    else
        dc = def.compute
    end
    if type(def.data) == "number" then
        dd = {def.data, def.data}
    else
        dd = def.data
    end
    if type(def.money) == "number" then
        dm = {def.money, def.money}
    else
        dm = def.money
    end
    g.VALID_JOBS[id] = {
        id = id,
        name = name,
        category = category,
        compute = {math.min(dc[1], dc[2]), math.max(dc[1], dc[2])},
        data = {math.min(dd[1], dd[2]), math.max(dd[1], dd[2])},
        money = {math.min(dm[1], dm[2]), math.max(dm[1], dm[2])},
    }
end

---@param id string
function g.genJob(id)
    local ji = g.VALID_JOBS[id]
    if not ji then
        error("unknown job id '"..id.."'")
    end

    local t = love.math.random()
    local cp = helper.lerp(ji.compute[1], ji.compute[2], t)
    cp = g.getProperty("getJobComputePower", cp, 1, id)
    local od = helper.lerp(ji.data[1], ji.data[2], t)
    od = g.getProperty("getJobOutputData", od, 1, id)
    local mr = helper.lerp(ji.money[1], ji.money[2], t)
    mr = g.getProperty("getJobMoneyReward", mr, 1, id)

    ---@type g.Job
    local job = {
        type = id,
        name = ji.name,
        -- FIXME: This is MSOT. Fortunately it's limited here. Gotta move fast.
        category = ji.category,
        computePower = helper.round(cp),
        outputData = helper.round(od),
        resource = {money = helper.round(mr)},
        timeout = g.getProperty("getJobTimeout", 0, 1, id),
    }
    g.call("jobCreated", job)
    return job
end

---@param job g.Job
function g.queueJob(job)
    local world = g.getMainWorld()

    if world.jobQueueCounts[job.category] >= world.maxJobQueues[job.category] then
        return false
    end

    world.jobQueue[#world.jobQueue+1] = job
    world.jobQueueCounts[job.category] = world.jobQueueCounts[job.category] + 1
    return true
end

end



---------------------
-- Items or Buildings
---------------------

do


---@class g._MixinHasNameDefinition
---@field public name string
---@field public nameContext string?
---@field public rawDescription string?
---@field public description string?
---@field public descriptionContext string?

---@class g._MixinHasNameInfo
---@field public name string
---@field public description string?


---@enum (key) g.ItemCategory
g.CATEGORIES = {
    server = true,
    data = true,
    indata = true,
    booster = true,
    powergen = true,
    powerrelay = true
}

---@class g.ItemDefinition: g._MixinHasNameDefinition
---@field public category g.ItemCategory
---@field public tags string[]?
---@field public price number
---@field public load number
---@field public drawItem fun(r: kirigami.Region) (not translated)
---@field public draw (fun(itemData: g.World.ItemData))? (already translated to center of tile)
---@field public getPriceMultiplier (fun(count:integer):number)?

---@class g.ItemInfo: g._MixinHasNameInfo
---@field public id string
---@field public category g.ItemCategory
---@field public tags objects.Set<string>
---@field public price number
---@field public load number
---@field public drawItem fun(r: kirigami.Region) (not translated)
---@field public draw fun(itemData: g.World.ItemData) (already translated to center of tile)
---@field public getPriceMultiplier fun(count:integer):number


---@alias g.RadiateAlgorithm "taxicab"|"chessboard"

---@class g._ServerInfoCommon
---@field public category "server"
---@field public computePerSecond number
---@field public computePreference string[]
---@field public heatTolerance [number, number]
---@field public heat number

---@class g.ServerInfo: g.ItemInfo, g._ServerInfoCommon
---@field public heatRadiate integer
---@field public heatRadiateAlgorithm g.RadiateAlgorithm

---@class g.ServerDefinition: g.ItemDefinition, g._ServerInfoCommon
---@field public heatRadiate integer? 1 is default
---@field public heatRadiateAlgorithm g.RadiateAlgorithm? Chessboard algorithm is default


---@class g._DataInfoCommon: g.ItemInfo
---@field public category "data"
---@field public dataPerSecond number
---@field public wireLength integer
---@field public wireDPS number

---@class g.DataOutInfo: g.ItemInfo, g._DataInfoCommon
---@class g.DataOutDefinition: g.ItemDefinition, g._DataInfoCommon


---@class g._DataInInfoCommon: g.ItemInfo
---@field public category "indata"
---@field public queuesJob g.JobCategory
---@field public maxJobQueue integer
---@field public wireLength integer

---@class g.DataInInfo: g.ItemInfo, g._DataInInfoCommon
---@field public jobFrequencyModifier number
---@field public jobFrequencyMultiplier number

---@class g.DataInDefinition: g.ItemDefinition, g._DataInInfoCommon
---@field public jobFrequencyModifier number?
---@field public jobFrequencyMultiplier number?


---@class g.BoosterInfo: g.ItemInfo
---@field public category "booster"
---@field public radiate integer
---@field public radiateAlgorithm g.RadiateAlgorithm
---@field public connectable {max:integer,target:g.ItemCategory}?
---@field public getTileHeat fun(reltx:integer,relty:integer):number
---@field public getPerformanceModifier fun(reltx:integer,relty:integer):number
---@field public getPerformanceMultiplier fun(reltx:integer,relty:integer):number
---@field public getLoadMultiplier fun(reltx:integer,relty:integer):number

---@class g.BoosterDefinition: g.ItemDefinition
---@field public category "booster"
---@field public radiate integer? 1 is default
---@field public radiateAlgorithm g.RadiateAlgorithm? Chessboard algorithm is default
---@field public connectable {max:integer,target:g.ItemCategory}? If exist, booster connects instead of radiate. Exceeding this connection reduces its effectiveness.
---@field public getTileHeat (fun(reltx:integer,relty:integer):number)?
---@field public getPerformanceModifier (fun(reltx:integer,relty:integer):number)?
---@field public getPerformanceMultiplier (fun(reltx:integer,relty:integer):number)?
---@field public getLoadMultiplier (fun(reltx:integer,relty:integer):number)?


---@class g.PowerGenInfo: g.ItemInfo
---@field public category "powergen"
---@field public power number
---@field public wireLength integer

---@class g.PowerGenDefinition: g.ItemDefinition
---@field public load? integer (forced to 0)
---@field public category "powergen"
---@field public power number
---@field public wireLength integer? (defaults to 1)


---@class g.PowerRelayInfo: g.ItemInfo
---@field public category "powerrelay"
---@field public wireLength integer

---@class g.PowerRelayDefinition: g.ItemDefinition
---@field public load? integer (forced to 0)
---@field public category "powerrelay"
---@field public wireLength integer? (defaults to 1)

---@type string[]
g.ITEMS = {}
---@type table<string, g.ItemInfo>
local itemList = {}

local function return0() return 0 end
local function return1() return 1 end
local function dummy() end

---@alias _ItemDef
---| g.ServerDefinition
---| g.DataInDefinition
---| g.DataOutDefinition
---| g.BoosterDefinition
---| g.PowerGenDefinition
---| g.PowerRelayDefinition

---@param id string
---@param def _ItemDef
function g.defineItem(id, def)
    if itemList[id] then
        error("Redefined item: "..id)
    end

    if not g.CATEGORIES[def.category] then
        error("Invalid category: "..def.category)
    end

    -- Set the name and description
    def.id = id
    def.draw = def.draw or dummy
    def.name = loc(def.name, nil, {context = def.nameContext})
    assert(not (def.rawDescription and def.description), "raw description and description is mutually exclusive")
    if def.rawDescription then
        def.description = def.rawDescription
    elseif def.description then
        def.description = loc(def.description, nil, {context = def.descriptionContext})
    end

    ---@cast def g.ItemInfo
    assert(def.price, "invalid price")
    def.getPriceMultiplier = def.getPriceMultiplier or return1
    if def.category == "powergen" or def.category == "powerrelay" then
        def.load = 0
    else
        assert(def.load, "invalid load")
    end
    def.tags = objects.Set(def.tags or {})

    if def.category == "server" then
        ---@cast def g.ServerInfo
        assert(def.computePerSecond, "invalid computePerSecond")
        assert(def.heatTolerance, "invalid heatTolerance")
        def.heatTolerance = {
            math.min(def.heatTolerance[1], def.heatTolerance[2]),
            math.max(def.heatTolerance[1], def.heatTolerance[2])
        }
        def.heatRadiate = def.heatRadiate or 1
        def.heatRadiateAlgorithm = def.heatRadiateAlgorithm or "chessboard"
        assert(#def.computePreference > 0)
        for _, jobCategory in ipairs(def.computePreference) do
            g.getJobCategoryName(jobCategory) -- just for assertion purpose
        end
    elseif def.category == "data" then
        ---@cast def g.DataOutInfo
        assert(def.dataPerSecond, "invalid dps")
        assert(def.wireLength and def.wireLength > 0, "invalid wire length")
        assert(def.wireDPS > 0, "invalid wire dps")
    elseif def.category == "indata" then
        ---@cast def g.DataInInfo
        assert(g.VALID_JOB_CATEGORIES[def.queuesJob], "invalid queuesJob")
        assert(def.maxJobQueue and def.maxJobQueue > 0, "invalid maxJobQueue")
        assert(def.wireLength and def.wireLength > 0, "invalid wireLength")
        def.jobFrequencyModifier = def.jobFrequencyModifier or 0
        def.jobFrequencyMultiplier = def.jobFrequencyMultiplier or 1
    elseif def.category == "booster" then
        ---@cast def g.BoosterInfo
        def.radiate = def.radiate or 1
        def.radiateAlgorithm = def.radiateAlgorithm or "chessboard"
        def.getTileHeat = def.getTileHeat or return0
        def.getPerformanceModifier = def.getPerformanceModifier or return0
        def.getPerformanceMultiplier = def.getPerformanceMultiplier or return1
        def.getLoadMultiplier = def.getLoadMultiplier or return1
        if def.connectable then
            assert(def.connectable.max and def.connectable.max > 0, "invalid max connections")
            assert(g.CATEGORIES[def.connectable.target], "invalid connect target")
        end
    elseif def.category == "powergen" then
        ---@cast def g.PowerGenInfo
        assert(def.power and def.power > 0, "invalid power")
        def.wireLength = math.floor(def.wireLength or 1)
        assert(def.wireLength > 0, "invalid wireLength")
    elseif def.category == "powerrelay" then
        ---@cast def g.PowerRelayInfo
        def.wireLength = math.floor(def.wireLength or 1)
        assert(def.wireLength > 0, "invalid wireLength")
    end

    itemList[id] = def
    g.ITEMS[#g.ITEMS+1] = id
end

---@param itemid string
---@param assertCategory g.ItemCategory?
---@return g.ItemInfo, g.ItemCategory
---@overload fun(itemid: string, assertCategory: "server"):(g.ServerInfo, "server")
---@overload fun(itemid: string, assertCategory: "data"):(g.DataOutInfo, "data")
---@overload fun(itemid: string, assertCategory: "indata"):(g.DataInInfo, "indata")
---@overload fun(itemid: string, assertCategory: "booster"):(g.BoosterInfo, "booster")
---@overload fun(itemid: string, assertCategory: "powergen"):(g.PowerGenInfo, "powergen")
---@overload fun(itemid: string, assertCategory: "powerrelay"):(g.PowerRelayInfo, "powerrelay")
function g.getItemInfo(itemid, assertCategory)
    local itemInfo = itemList[itemid]
    if not itemInfo then
        error("unknown item id '"..itemid.."'")
    end

    if assertCategory and itemInfo.category ~= assertCategory then
        error("item '"..itemid.."' is not '"..assertCategory.."'")
    end

    return itemInfo, itemInfo.category
end

g.PREUNLOCKED_ITEMS = objects.Set()

---@param itemid string
function g.isItemUnlocked(itemid)
    if not g.isValidItem(itemid) then
        error("unknown item id '"..itemid.."'")
    end

    return g.ask("isItemUnlocked", itemid) or g.PREUNLOCKED_ITEMS:contains(itemid) or FLAGS.UNLOCK_ALL_ITEMS
end

---@param itemid string
function g.isValidItem(itemid)
    return not not itemList[itemid]
end

---@param itemid string|g.ItemInfo
---@param count integer?
function g.getItemPrice(itemid, count)
    if type(itemid) == "string" then
        itemid = g.getItemInfo(itemid)
    end

    if not count then
        local world = g.getMainWorld()
        count = world.itemCounts[itemid.id]
    end

    return itemid.price * itemid.getPriceMultiplier(math.max(count, 0))
end



-- Quick item registration for specific category

local drawLockOpen = helper.genDrawUIIntuition("lock_open", "theme", "theme")

---@class g._CommonSpecificItemDef
---@field nameContext string?
---@field rawDescription string?
---@field description string?
---@field descriptionContext string?
---@field tags string[]?
---@field color objects.Color
---@field price number
---@field getPriceMultiplier (fun(count:integer):number)?
---@field load number

---@class g._ServerDef: g._CommonSpecificItemDef
---@field computePerSecond number
---@field computePreference string[]
---@field heatTolerance [number, number]
---@field heat number
---@field draw fun(r:kirigami.Region,itemData:g.World.ServerData?)?

---@param id string
---@param name string
---@param def g._ServerDef
function g.defineServer(id, name, def)
    g.defineUpgrade(id, name, {
        description = def.description,
        descriptionContext = def.descriptionContext,
        getPriceOverride = function() return {money = def.price} end,
        kind = "UNLOCKS",
        targetItem = id,
        maxLevel = 1,
        drawUI = function(uinfo, level, r)
            -- Draw server
            local r2 = worldutil.drawServerShape(r:padRatio(0.125), def.color)
            if def.draw then
                def.draw(r2)
            end
            drawLockOpen(uinfo, level, r)
        end,
        isItemUnlocked = function(uinfo, level, iid)
            return iid == id
        end
    })
    return g.defineItem(id, {
        category = "server",
        name = name,
        nameContext = def.nameContext,
        rawDescription = def.rawDescription,
        description = def.description,
        descriptionContext = def.descriptionContext,
        tags = def.tags,
        load = def.load,
        price = def.price,
        getPriceMultiplier = def.getPriceMultiplier,
        computePerSecond = def.computePerSecond,
        computePreference = def.computePreference,
        heatTolerance = def.heatTolerance,
        heat = def.heat,
        draw = function(itemData)
            ---@cast itemData g.World.ServerData
            local wtz = consts.WORLD_TILE_SIZE * 0.75
            local r = Kirigami(-wtz / 2, -wtz / 2, wtz, wtz)
            local r2 = worldutil.drawServerShape(r, def.color)
            if def.draw then
                def.draw(r2, itemData)
            end
        end,
        drawItem = function(r)
            local r2 = worldutil.drawServerShape(r, def.color)
            if def.draw then
                def.draw(r2)
            end
        end
    })
end

---@class g._DataDef: g._CommonSpecificItemDef
---@field dataPerSecond number
---@field wireLength integer
---@field wireDPS number? (defaults to dataPerSecond / 4)
---@field draw fun(r:kirigami.Region,itemData:g.World.DataOutputData?)

---@param id string
---@param name string
---@param def g._DataDef
function g.defineDataOutput(id, name, def)
    g.defineUpgrade(id, name, {
        description = def.description,
        descriptionContext = def.descriptionContext,
        getPriceOverride = function() return {money = def.price} end,
        kind = "UNLOCKS",
        targetItem = id,
        maxLevel = 1,
        drawUI = function(uinfo, level, r)
            -- Draw data output
            local r2 = worldutil.drawDataOutShape(r:padRatio(0.125), def.color)
            if def.draw then
                def.draw(r2)
            end
            drawLockOpen(uinfo, level, r)
        end,
        isItemUnlocked = function(uinfo, level, iid)
            return iid == id
        end
    })
    return g.defineItem(id, {
        category = "data",
        name = name,
        nameContext = def.nameContext,
        rawDescription = def.rawDescription,
        description = def.description,
        descriptionContext = def.descriptionContext,
        tags = def.tags,
        price = def.price,
        getPriceMultiplier = def.getPriceMultiplier,
        load = def.load,
        dataPerSecond = def.dataPerSecond,
        wireLength = def.wireLength,
        wireDPS = def.wireDPS or (def.dataPerSecond / 4),
        draw = function(itemData)
            ---@cast itemData g.World.DataOutputData
            local wtz = consts.WORLD_TILE_SIZE * 0.75
            local r = Kirigami(-wtz / 2, -wtz / 2, wtz, wtz)
            local r2 = worldutil.drawDataOutShape(r, def.color)
            if def.draw then
                def.draw(r2, itemData)
            end
        end,
        drawItem = function(r)
            local r2 = worldutil.drawDataOutShape(r, def.color)
            if def.draw then
                def.draw(r2)
            end
        end
    })
end

---@class g._DataInDef: g._CommonSpecificItemDef
---@field queuesJob g.JobCategory
---@field maxJobQueue integer
---@field jobFrequencyModifier number?
---@field jobFrequencyMultiplier number?
---@field wireLength integer
---@field draw fun(r:kirigami.Region,itemData:g.World.ItemData?)?

---@param id string
---@param name string
---@param def g._DataInDef
function g.defineDataInput(id, name, def)
    g.defineUpgrade(id, name, {
        description = def.description,
        descriptionContext = def.descriptionContext,
        getPriceOverride = function() return {money = def.price * 2} end,
        kind = "UNLOCKS",
        targetItem = id,
        maxLevel = 1,
        drawUI = function(uinfo, level, r)
            -- Draw data input (same shape as output for now)
            local r2 = worldutil.drawDataInShape(r:padRatio(0.125), def.color)
            if def.draw then
                def.draw(r2)
            end
            drawLockOpen(uinfo, level, r)
        end,
        isItemUnlocked = function(uinfo, level, iid)
            return iid == id
        end
    })
    return g.defineItem(id, {
        category = "indata",
        name = name,
        nameContext = def.nameContext,
        rawDescription = def.rawDescription,
        description = def.description,
        descriptionContext = def.descriptionContext,
        tags = def.tags,
        price = def.price,
        getPriceMultiplier = def.getPriceMultiplier,
        load = def.load,
        queuesJob = def.queuesJob,
        maxJobQueue = def.maxJobQueue,
        jobFrequencyModifier = def.jobFrequencyModifier,
        jobFrequencyMultiplier = def.jobFrequencyMultiplier,
        wireLength = def.wireLength,
        draw = function(itemData)
            ---@cast itemData g.World.ItemData
            local wtz = consts.WORLD_TILE_SIZE * 0.75
            local r = Kirigami(-wtz / 2, -wtz / 2, wtz, wtz)
            local r2 = worldutil.drawDataInShape(r, def.color)
            if def.draw then
                def.draw(r2, itemData)
            end
        end,
        drawItem = function(r)
            local r2 = worldutil.drawDataInShape(r, def.color)
            if def.draw then
                def.draw(r2)
            end
        end
    })
end

---@class g._BoosterDef: g._CommonSpecificItemDef
---@field radiate integer
---@field radiateAlgorithm g.RadiateAlgorithm
---@field connectable {max:integer,target:g.ItemCategory}?
---@field draw fun(r:kirigami.Region,itemData:g.World.ItemData?)
---@field getTileHeat (fun(reltx:integer,relty:integer):number)?
---@field getPerformanceModifier (fun(reltx:integer,relty:integer):number)?
---@field getPerformanceMultiplier (fun(reltx:integer,relty:integer):number)?
---@field getLoadMultiplier (fun(reltx:integer,relty:integer):number)?

---@param id string
---@param name string
---@param def g._BoosterDef
function g.defineBooster(id, name, def)
    g.defineUpgrade(id, name, {
        description = def.description,
        descriptionContext = def.descriptionContext,
        getPriceOverride = function() return {money = def.price * 3} end,
        kind = "UNLOCKS",
        targetItem = id,
        maxLevel = 1,
        drawUI = function(uinfo, level, r)
            -- Draw data output
            local r2 = worldutil.drawBoosterShape(r:padRatio(0.125), def.color)
            if def.draw then
                def.draw(r2)
            end
            drawLockOpen(uinfo, level, r)
        end,
        isItemUnlocked = function(uinfo, level, iid)
            return iid == id
        end
    })
    return g.defineItem(id, {
        category = "booster",
        name = name,
        nameContext = def.nameContext,
        rawDescription = def.rawDescription,
        description = def.description,
        descriptionContext = def.descriptionContext,
        tags = def.tags,
        price = def.price,
        getPriceMultiplier = def.getPriceMultiplier,
        load = def.load,
        radiate = def.radiate,
        radiateAlgorithm = def.radiateAlgorithm,
        connectable = def.connectable,
        getTileHeat = def.getTileHeat,
        getPerformanceModifier = def.getPerformanceModifier,
        getPerformanceMultiplier = def.getPerformanceMultiplier,
        getLoadMultiplier = def.getLoadMultiplier,

        draw = function(itemData)
            ---@cast itemData g.World.ItemData
            local wtz = consts.WORLD_TILE_SIZE * 0.75
            local r = Kirigami(-wtz / 2, -wtz / 2, wtz, wtz)
            local r2 = worldutil.drawBoosterShape(r, def.color)
            if def.draw then
                def.draw(r2, itemData)
            end
        end,
        drawItem = function(r)
            local r2 = worldutil.drawBoosterShape(r, def.color)
            if def.draw then
                def.draw(r2)
            end
        end
    })
end

---@class g._PowerGenDef: g._CommonSpecificItemDef
---@field load number? (always 0)
---@field power number
---@field wireLength integer
---@field draw fun(r:kirigami.Region,itemData:g.World.ItemData?)?

---@param id string
---@param name string
---@param def g._PowerGenDef
function g.definePowerGenerator(id, name, def)
    g.defineUpgrade(id, name, {
        description = def.description,
        descriptionContext = def.descriptionContext,
        getPriceOverride = function() return {money = def.price} end,
        kind = "UNLOCKS",
        targetItem = id,
        maxLevel = 1,
        drawUI = function(uinfo, level, r)
            -- Draw power generator
            local r2 = worldutil.drawPowerGenShape(r:padRatio(0.125), def.color)
            if def.draw then
                def.draw(r2)
            end
            drawLockOpen(uinfo, level, r)
        end,
        isItemUnlocked = function(uinfo, level, iid)
            return iid == id
        end
    })
    return g.defineItem(id, {
        category = "powergen",
        name = name,
        nameContext = def.nameContext,
        rawDescription = def.rawDescription,
        description = def.description,
        descriptionContext = def.descriptionContext,
        tags = def.tags,
        price = def.price,
        getPriceMultiplier = def.getPriceMultiplier,
        load = 0,
        power = def.power,
        wireLength = def.wireLength,
        draw = function(itemData)
            ---@cast itemData g.World.ItemData
            local wtz = consts.WORLD_TILE_SIZE * 0.75
            local r = Kirigami(-wtz / 2, -wtz / 2, wtz, wtz)
            local r2 = worldutil.drawPowerGenShape(r, def.color)
            if def.draw then
                def.draw(r2, itemData)
            end
        end,
        drawItem = function(r)
            local r2 = worldutil.drawPowerGenShape(r, def.color)
            if def.draw then
                def.draw(r2)
            end
        end
    })
end

---@class g._PowerRelayDef: g._CommonSpecificItemDef
---@field load number? (always 0)
---@field wireLength integer
---@field draw fun(r:kirigami.Region,itemData:g.World.ItemData?)?

---@param id string
---@param name string
---@param def g._PowerRelayDef
function g.definePowerRelay(id, name, def)
    g.defineUpgrade(id, name, {
        description = def.description,
        descriptionContext = def.descriptionContext,
        getPriceOverride = function() return {money = def.price / 2} end,
        kind = "UNLOCKS",
        targetItem = id,
        maxLevel = 1,
        drawUI = function(uinfo, level, r)
            -- Draw power relay
            local r2 = worldutil.drawPowerRelayShape(r:padRatio(0.125), def.color)
            if def.draw then
                def.draw(r2)
            end
            drawLockOpen(uinfo, level, r)
        end,
        isItemUnlocked = function(uinfo, level, iid)
            return iid == id
        end
    })
    return g.defineItem(id, {
        category = "powerrelay",
        name = name,
        nameContext = def.nameContext,
        rawDescription = def.rawDescription,
        description = def.description,
        descriptionContext = def.descriptionContext,
        tags = def.tags,
        price = def.price,
        getPriceMultiplier = def.getPriceMultiplier,
        load = 0,
        wireLength = def.wireLength,
        draw = function(itemData)
            ---@cast itemData g.World.ItemData
            local wtz = consts.WORLD_TILE_SIZE * 0.75
            local r = Kirigami(-wtz / 2, -wtz / 2, wtz, wtz)
            local r2 = worldutil.drawPowerRelayShape(r, def.color)
            if def.draw then
                def.draw(r2, itemData)
            end
        end,
        drawItem = function(r)
            local r2 = worldutil.drawPowerRelayShape(r, def.color)
            if def.draw then
                def.draw(r2)
            end
        end
    })
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
---@return g.World.ItemData?
function g.getItem(tx, ty)
    local world = g.getMainWorld()

    if world.items:contains(tx, ty) then
        return world.items:get(tx, ty)
    end

    return nil
end

---@param item g.World.ItemData
---@return boolean
---@diagnostic disable-next-line: duplicate-set-field, missing-return
function g.removeItem(item) end

---@param tx integer
---@param ty integer
---@diagnostic disable-next-line: duplicate-set-field
function g.removeItem(tx, ty)
    local world = g.getMainWorld()
    local item
    if type(tx) == "table" then
        ---@cast tx g.World.ItemData
        item = tx
        tx, ty = item.tileX, item.tileY
        assert(world.items:get(tx, ty) == item, "position source of truth violation")
    else
        item = world.items:get(tx, ty)
    end

    local ok = false
    if item then
        item.removed = true
        ok = true
    end
    world.items:set(tx, ty, nil)
    return ok
end

---@param targetItem g.World.ItemData
---@param tx integer
---@param ty integer
function g.moveItem(targetItem, tx, ty)
    if not g.canPutItem(tx, ty) then
        error("unable to put item at "..tx..","..ty)
    end

    local world = g.getMainWorld()
    assert(world.items:get(targetItem.tileX, targetItem.tileY) == targetItem, "position source of truth violation")
    world.items:set(targetItem.tileX, targetItem.tileY, nil)
    world.items:set(tx, ty, targetItem)
    targetItem.tileX = tx
    targetItem.tileY = ty
end

---@param server g.World.ServerData
---@param dp g.World.DataOutputData
function g.disconnectDataWire(server, dp)
    for i, s in ipairs(dp.connectsServers) do
        if s == server then
            table.remove(dp.connectsServers, i)
            return
        end
    end

    error("not connected")
end

---This only checks the server position and DP wire length/count
---@param server g.World.ServerData
---@param dp g.World.DataOutputData
function g.canConnectDataWire(server, dp)
    local dpInfo = g.getItemInfo(dp.type, "data")
    if worldutil.getDistance("chessboard", server.tileX - dp.tileX, server.tileY - dp.tileY) > dpInfo.wireLength then
        return false
    end

    return true
end

---@param server g.World.ServerData
---@param dp g.World.DataOutputData
function g.connectDataWire(server, dp)
    if helper.index(dp.connectsServers, server) then
        error("already connected")
    end

    if not g.canConnectDataWire(server, dp) then
        error("cannot connect data wire")
    end

    dp.connectsServers[#dp.connectsServers+1] = server
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
    -- No suitable data output found
    no_suitable_output = {
        error = true,
        icon = "database",
        text = loc("No suitable data output found for the current data load!", nil, {
            context = "The server cannot find any data output that can handle its data load."}),
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
        error = false,
        icon = "database",
        text = loc("Data output or wire is overloaded!", nil, {
            context = "The server is sending data slower than its peak capacity."}),
    }
}

---@param itemData g.World.ItemData
function g.getItemProblems(itemData)
    ---@type g.ItemProblems[]
    local result = {}

    if not itemData.powerNetwork then
        result[#result+1] = "no_power"
    elseif itemData.powerNetwork.totalLoad > itemData.powerNetwork.totalPower then
        result[#result+1] = "overloaded"
    end

    local itemInfo, category = g.getItemInfo(itemData.type)

    if category == "server" then
        ---@cast itemData g.World.ServerData
        ---@cast itemInfo g.ServerInfo
        local nInputs = #itemData.connectedInputs
        local nOutputs = #itemData.connectedOutputs

        if nOutputs == 0 and nInputs == 0 then
            result[#result+1] = "no_io_connection"
        elseif nOutputs == 0 then
            result[#result+1] = "not_connected"
        elseif nInputs == 0 then
            result[#result+1] = "no_input_connection"
        end

        if itemData.currentJob and not itemData.activeOutput then
            result[#result+1] = "no_suitable_output"
        end

        if itemData.dataBottlenecked then
            result[#result+1] = "data_bottleneck"
        end

        if g.getTileHeat(itemData.tileX, itemData.tileY) > itemInfo.heatTolerance[2] then
            result[#result+1] = "overheat"
        end
    elseif category == "data" then
        ---@cast itemData g.World.DataOutputData
        ---@cast itemInfo g.DataOutInfo
        if #itemData.connectsServers == 0 then
            result[#result+1] = "no_connection"
        end
    elseif category == "indata" then
        ---@cast itemData g.World.DataInputData
        ---@cast itemInfo g.DataInInfo
        if #itemData.connectsServers == 0 then
            result[#result+1] = "input_not_connected"
        end
    end

    return result
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
        JOB = objects.Color("#61d4b1"),
        MISC = objects.Color("#c4d14d"),
        FALLBACK = objects.Color.WHITE,
    },

    SHADOW = objects.Color(0,0,0,0.4),

    CRIT = objects.Color("FFA43929"),

    CANT_AFFORD = objects.Color("FFD72D2D"),
    CAN_AFFORD = objects.Color("FF73FF73"),

    MONEY = objects.Color("FFF7D127"),
    RECOMMENDED = objects.Color("FF9DEC4E"),
    UPGRADE_CONNECTOR = objects.Color("FF000000"),

    RARITIES = {
        [0] = objects.Color("FF8A8A8A"), -- Common (grey)
        [1] = objects.Color("FF4A9EFF"), -- Rare (blue)
        [2] = objects.Color("FFFFD700"), -- Legendary (gold)
    },

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
    },

    TILE_HOT = objects.Color("7fD63900"),
    TILE_COLD = objects.Color("7fabeeff"),
}

do
for k,v in pairs(g.COLORS) do
    if getmetatable(v) == objects.Color then
        richtext.defineEffect(k, function (args, x,y, context, next)
            local r,gg,b,a = lg.getColor()
            lg.setColor(v)
            next(context.textOrDrawable, x,y)
            lg.setColor(r,gg,b,a)
        end)
    end
end
end


return g
