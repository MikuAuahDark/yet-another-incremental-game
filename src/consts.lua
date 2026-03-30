

---@class consts
local consts = {

    DEV_MODE = not not (love.filesystem.getInfo(".git", "directory") and os.getenv("DISABLE_DEV_MODE") ~= "1"),
    SHOW_DEV_STUFF = false, -- can be toggled on/off (eg for screenshots)

    EMULATE_TOUCH = os.getenv("INCREMENTAL_GAME_EMULATE_TOUCH") == "1", -- Set later
    IS_MOBILE = false, -- Set later

    PROFILING = false,

    ANALYTICS_URL = nil, -- URL, without trailing slash.
    -- How long it should take before sending "update" event to analytics server (in seconds)?
    ANALYTICS_UPDATE_INTERVAL = 60,
    GAME_VERSION = 0,
    ANALYTICS_IDENTITY = "make_a_datacenter",

    FILE_LOG_LEVEL = "trace",
    CONSOLE_LOG_LEVEL = "trace",

    FILE_SEP = "/",

    DEV_UPGRADE_TREE_PATH = "trees",

    TARGET_TIME_PER_LEVEL_UP = 25,

    ATLAS_SIZE = 2048,

    MAX_PLAYING_SOURCES = 14,

    UPGRADE_IMAGE_SIZE = 32,
    UPGRADE_GRID_SPACING = 8, -- spaced 8 units apart
    UPGRADE_CONNECTOR_WIDTH = 8,

    HARVEST_AREA_LEEWAY = 4, -- Mouse-harvest extends by this amount so it "feels good"

    VIGNETTE_STRENGTH = 0.6,

    DEFAULT_UPGRADE_PRICE_SCALING = 1,
    -- upgrade-price is multiplied by this amount every level (unless specified)
    -- 1 => upgrade price doesnt change per level

    DEFAULT_UPGRADE_MAX_LEVEL = 10,

    TEST = true,

    WORLD_TILE_SIZE = 32, -- World tile size on both width and height.

    DRAG_ITEM_DURATION = 0.5,
}

if not consts.DEV_MODE then
    consts.CONSOLE_LOG_LEVEL = "error"
end

local os = love.system.getOS()
consts.EMULATE_TOUCH = consts.DEV_MODE and consts.EMULATE_TOUCH
consts.IS_MOBILE = os == "Android" or os == "iOS" or consts.EMULATE_TOUCH
consts.SHOW_DEV_STUFF = consts.DEV_MODE


return consts
