-- Simple file containing list translation text
-- This is to ensure all translation text are in one place as possible.

-- If you need to apply effect to whole text, don't apply it here.
-- Apply it in the code that uses such text instead!

---@class TEXTLIST
local text = {
    JOB_QUEUE_INFO = loc("Tasks", nil, {
        context = "Used in place to list available task categories"}),
    MONEY = loc("Money", nil, {
        context = "A resource"}),
    MONEY_DESCRIPTION = loc("Use the money to buy servers, data output, boosters, and unlock upgrades.", nil, {
        context = "A description on what \"Money\" (a resource in-game) is usable for."}),
    CPS = loc("Compute Per Second", nil, {
        context = "CPS (Compute Per Second) is a measurement how fast server can process computation."}),
    CPS_DESCRIPTION = loc("This is how fast all your servers perform computation for its job. The win condition is to reach {b}1 million{/b} CPS.", nil, {
        context = "A description on what \"CPS\" (Compute Per Second) is for."}),

    CATEGORY_LIST = interp("Category: %{categories}", {
        context = "Denoting list of category, the ${categories} will be replaced with the actual list of items later"}),
    CATEGORY_SERVER = loc("Servers", nil, {
        context = "Denotes the category of server buildings"}),
    CATEGORY_DATA = loc("Data I/O", nil, {
        context = "Denotes the category of data input or data output buildings"}),
    CATEGORY_BOOSTER = loc("Boosters", nil, {
        context = "Denotes the category of booster buildings used to boost server performance"}),
    CATEGORY_POWER = loc("Power", nil, {
        context = "Denotes the category of power buildings used to provide power to other buildings"}),

    CPS_NUMBER = interp("%{cps} {dns}/second", {
        context = "CPS (Compute Per Second) is a measurement how fast server can process computation. {dns} reflects \"Compute\" icon in-game."}),
    SERVER_HEAT_NUMBER = interp("%{heat}/%{max_heat} Heat", {
        context = "Denotes heat of a machine."}),
    DPS_NUMBER = interp("%{dps} {database}/second", {
        context = "DPS (Data Per Second) is a measurement how fast data output can process data. {database} reflects \"Data\" icon in-game."}),
    WIRE_DPS = interp("Wire {COLORS_UI_TEXT_DPS}%{dps} {database}/second{/COLORS_UI_TEXT_DPS}", {
        context = "Denotes the speed of data transfer."}),
    WIRE_COUNT = interp("Connections: %{count}/%{max}", {
        context = "Denotes the (max) number of connections that can be handled by this machine/item."}),
    EFFECTIVITY = interp("Effectivity: %{effectivity}%", {
        context = "Denotes the effectivity of a booster. The %{effectivity} is percentage of the booster efficiency."}),
    HEAT_TOLERANCE = interp("Heat Tolerance: %{min_heat}-%{max_heat}", {
        context = "Denotes the heat tolerance range of a machine."}),
    LOAD_TOOLTIP = interp("Load: {COLORS_UI_TEXT_POWER_RELATED}%{load}{bolt}{/COLORS_UI_TEXT_POWER_RELATED}", {
        context = "How many load this item uses?"}),
    PROVIDE_LOAD_TOOLTIP = interp("Generates: {COLORS_UI_TEXT_POWER_RELATED}%{load}{bolt}{/COLORS_UI_TEXT_POWER_RELATED}", {
        context = "How many load this item generates/provides?"}),
    TOTAL_LOAD_TOOLTIP = interp("Power Network: %{s}", {
        context = "How many load is used and power available across the whole power network? %{s} will be replaced by `load/total`."}),
    LEVEL_TOOLTIP = interp("Level: %{level}", {
        context = "Denotes the level of an upgrade."}),
    JOB_FREQUENCY_MODIFIER = interp("+%{modifier}s %{jobtype} tasks.", {
        context = "Denotes the job frequency modifier of a data input."}),
    JOB_FREQUENCY_MULTIPLIER = interp("%{multiplier}% %{jobtype} tasks.", {
        context = "Denotes the job frequency multiplier of a data input."}),

    MENU_CONTINUE = loc("Continue", nil, {
        context = "A button to continue the game from title screen"}),
    MENU_NEW_GAME = loc("New Game", nil, {
        context = "A button to start a new game from title screen"}),
    MENU_SETTINGS = loc("Settings", nil, {
        context = "A button to open game settings, either from title screen or from pause menu"}),
    MENU_QUIT_GAME = loc("Quit", nil, {
        context = "A button to quit/exit the game"}),

    SETTING_TITLE = loc("Settings", nil, {
        context = "Title of the settings screen"}),
    SETTING_GENERAL = loc("General", nil, {
        context = "Category of settings"}),
    SETTING_AUDIO = loc("Audio", nil, {
        context = "Category of settings"}),

    TUTORIAL_SKIP = loc("Skip", nil, {
        context = "A button to skip the current tutorial"}),
    TUTORIAL_NEXT = loc("Next", nil, {
        context = "A button to advance to the next step in the tutorial"}),
    -- FIXME: My English for this tutorial
    TUTORIAL_0_1 = loc("Let's start by placing server on the area.", nil, {
        context = "Tutorial on placing server"}),
    TUTORIAL_0_2 = interp("Click the %{server} on the bottom and click anywhere on the world to place it.", {
        context = "Tutorial on placing server"}),
    TUTORIAL_1_1 = loc("Now, time to place data inputs. Data input provides tasks to the server.", nil, {
        context = "Tutorial on placing data inputs"}),
    TUTORIAL_1_2 = interp("Press the \"%{CATEGORY_DATA}\" to show the data inputs.", {
        context = "Tutorial on placing data inputs"}),
    TUTORIAL_1_3 = interp("Click the %{di} on the bottom and click near the server on the world to place it.", {
        context = "Tutorial on placing data inputs"}),
    TUTORIAL_2_1 = loc("Now, time to place data outputs. Server will process a data fragment that needs to be send to data output to earn money.", nil, {
        context = "Tutorial on placing data outputs"}),
    TUTORIAL_2_2 = interp("Click the %{do} on the bottom and click near the server on the world to place it.", {
        context = "Tutorial on placing data outputs"}),
    TUTORIAL_3_1 = loc("You should see data moving by hovering on the data input, server, or the data outputs. If not, try to move them closer to each other.", nil, {
        context = "Tutorial on verifying pipeline"}),
    TUTORIAL_3_2 = loc("If you see yellow or red indicator above the items, that means something's' wrong. Hover to it to see more information.", nil, {
        context = "Tutorial on verifying pipeline"}),
    TUTORIAL_4_1 = loc("You can remove buildings from the world by using the {c r=1 g=0 b=0}Delete{/c} tool on the bottom right.", nil, {
        context = "Tutorial on removing buildings"}),
    TUTORIAL_4_2 = loc("To use it, click on it then click items you want to remove. Once removed, they'll be put back into your storage.", nil, {
        context = "Tutorial on removing buildings"}),
}
return text
