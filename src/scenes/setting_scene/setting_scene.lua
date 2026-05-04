local FreeCameraScene = require("src.scenes.FreeCameraScene")
local sceneManager = require("src.scenes.sceneManager")

---@class SettingScene: FreeCameraScene
local SettingScene = FreeCameraScene()



---@class _SettingEntry
---@field package text string
---@field package type "toggle"|"slider"|"button"
---@class _BooleanEntry: _SettingEntry
---@field package type "toggle"
---@field package getter fun():boolean
---@field package setter fun(v:boolean)
---@class _SliderEntry: _SettingEntry
---@field package type "slider"
---@field package getter fun():integer
---@field package setter fun(v:integer)
---@field package min integer
---@field package max integer
---@class _ButtonEntry: _SettingEntry
---@field package type "button"
---@field package buttonLabel string
---@field package action fun()

---@type table<string, (_BooleanEntry|_SliderEntry|_ButtonEntry)[]>
local SETTINGS = {
    general = {
        {
            text = loc("Fullscreen"),
            type = "toggle",
            getter = settings.isFullscreen,
            setter = settings.setFullscreen
        },
        {
            text = loc("New Game Tutorial"),
            type = "toggle",
            getter = settings.isTutorialShown,
            setter = settings.setTutorialShown
        },
        {
            text = loc("Language"),
            type = "button",
            buttonLabel = settings.getLanguage(),
            action = function()
                -- TODO
            end
        },
        {
            text = loc("Credits"),
            type = "button",
            buttonLabel = "Show",
            action = function()
                -- TODO
            end
        }
    },
    audio = {
        {
            text = loc("Main Volume"),
            type = "slider",
            getter = settings.getMasterVolume,
            setter = settings.setMasterVolume,
            min = 0,
            max = 100
        },
        {
            text = loc("Music Volume"),
            type = "slider",
            getter = settings.getBGMVolume,
            setter = settings.setBGMVolume,
            min = 0,
            max = 100
        },
        {
            text = loc("SFX Volume"),
            type = "slider",
            getter = settings.getSFXVolume,
            setter = settings.setSFXVolume,
            min = 0,
            max = 100
        }
    }
}

function SettingScene:init()
    self.allowMousePan = false
    self.activeTab = "general"
end

function SettingScene:update(dt)
end

function SettingScene:draw()
    ui.startUI()

    local theme = g.getSystemTheme()
    local titleF = g.getThickFont(32)
    local tabF = g.getThickFont(20)
    local r = ui.getScreenRegion()
    local areaR = r:padRatio(0.1)

    love.graphics.clear(g.COLORS.UI.MAIN[theme].PRIMARY)

    local titleR, _, contentBaseR = helper.splitRegionByExactSizes(areaR, "vertical",
        titleF:getHeight(),
        8,
        0
    )

    love.graphics.setColor(1, 1, 1)
    ui.printRichInRegion("{o}"..TEXT.SETTING_TITLE.."{/o}", titleF, titleR, true, "center", "center")

    local TRAPEZOID_PADDING = 10
    local tabR, contentR = helper.splitRegionByExactSizes(contentBaseR, "vertical", tabF:getHeight(), 0)
    local generalTabR, audioTabR = tabR:splitHorizontal(1, 1)
    local tabs = {
        general = {generalTabR, TEXT.SETTING_GENERAL},
        audio = {audioTabR, TEXT.SETTING_AUDIO},
    }
    love.graphics.setColor(g.COLORS.UI.MAIN[theme].PANEL)
    love.graphics.rectangle("fill", contentR:get())
    for k, v in pairs(tabs) do
        -- Input test
        if iml.wasJustClicked(v[1]:get()) then
            self.activeTab = k
        end
        -- Distinct active tab with inactive tabs
        if self.activeTab == k then
            love.graphics.setColor(g.COLORS.UI.MAIN[theme].PANEL)
        else
            love.graphics.setColor(g.COLORS.UI.MAIN[theme].TAB_INACTIVE)
        end
        -- Draw trapezoid using the padding
        do
            local x, y, w, h = v[1]:get()
            love.graphics.polygon("fill", {
                x + TRAPEZOID_PADDING, y,
                x + w - TRAPEZOID_PADDING, y,
                x + w, y + h,
                x, y + h,
            })
        end
        -- Draw tab name
        love.graphics.setColor(g.COLORS.UI.MAIN[theme].TEXT)
        ui.printRichInRegion(v[2], tabF, v[1], true, "center")
    end

    -- Draw setting for each category
    local baseSettingR = contentR:padRatio(0.3, 0.1)
    local leftListR, rightListR = baseSettingR:splitHorizontal(3, 2)
    local settingF = g.getMainFont(20)
    local leftList = leftListR:grid(1, math.floor(leftListR.h / (settingF:getHeight() + 8)))
    local rightList = rightListR:grid(1, math.floor(rightListR.h / (settingF:getHeight() + 8)))
    for i, s in ipairs(SETTINGS[self.activeTab]) do
        local leftR = leftList[i]:padUnit(0, 8)
        local rightR = rightList[i]:padUnit(0, 8)
        love.graphics.setColor(g.COLORS.UI.MAIN[theme].TEXT)
        love.graphics.print(s.text, settingF, leftR.x, leftR.y)
        love.graphics.setColor(1, 1, 1)

        if s.type == "toggle" then
            local c = g.COLORS.UI.MAIN[theme].PRIMARY_INVERT
            local checkboxR = rightR:shrinkToAspectRatio(1, 1):center(rightR)
            local oldval = s.getter()
            local newval = ui.Checkbox(g.COLORS.UI.MAIN[theme].CARD, checkboxR, oldval, c)
            if oldval ~= newval then
                s.setter(newval)
            end
        elseif s.type == "slider" then
            local valwidth = settingF:getWidth(tostring(s.max)..tostring(s.min))
            local sliderBaseR, valueR = helper.splitRegionByExactSizes(rightR, "horizontal", 0, valwidth)
            local sliderR = sliderBaseR:padUnit(2)
            local oldval = s.getter()

            love.graphics.setColor(g.COLORS.UI.MAIN[theme].PRIMARY_INVERT)
            love.graphics.rectangle("fill", sliderBaseR:get())
            love.graphics.setColor(g.COLORS.UI.MAIN[theme].TEXT)
            local newval = s.min + ui.Slider(
                s.text..s.type,
                "horizontal",
                g.COLORS.UI.MAIN[theme].PRIMARY,
                oldval - s.min + 1,
                s.max - s.min + 1,
                0.15,
                sliderR
            ) - 1
            if oldval ~= newval then
                s.setter(newval)
            end
            love.graphics.setColor(g.COLORS.UI.MAIN[theme].TEXT)
            love.graphics.printf(tostring(newval), settingF, valueR.x, valueR.y, valueR.w, "center")
        elseif s.type == "button" then
            local c = g.COLORS.UI.MAIN[theme].PRIMARY_INVERT
            love.graphics.setColor(1, 1, 1)
            if ui.Button2(s.buttonLabel, settingF, c, rightR, c, g.COLORS.UI.MAIN[theme].PRIMARY) then
                s.action()
            end
        end
    end

    -- Draw back button
    love.graphics.setColor(1, 1, 1)
    local backButtonR = Kirigami(0, 0, 40, 40)
        :attachToLeftOf(r)
        :attachToTopOf(r)
        :moveRatio(1, 1)
        :moveUnit(4, 4)
    ui.Tooltip(backButtonR, objects.Color.BLACK, objects.Color.WHITE)
    g.drawImageContained("arrow_back", backButtonR:padUnit(ui.TOOLTIP_PADDING):get())
    if iml.wasJustClicked(backButtonR:get()) then
        sceneManager.gotoLastScene()
    end

    ui.endUI()
end

function SettingScene:keyreleased(k)
    if k == "escape" then
        sceneManager.gotoLastScene()
    end
end

return SettingScene
