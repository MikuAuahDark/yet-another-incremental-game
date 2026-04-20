-- Simple file containing list translation text
-- This is to ensure all translation text are in one place as possible.

---@class TEXTLIST
local text = {
    HORIZONTAL_LIST_SEPARATOR = loc(", ", nil, {
        context = "A separator symbol used to denote item list in single horizontal text"}),

    JOB_QUEUE_INFO = loc("Task Queues", nil, {
        context = "Used in place to list tasks, with specific maximum amount of queueable tasks"}),
    MONEY = loc("Money", nil, {
        context = "A resource"}),
    MONEY_DESCRIPTION = loc("Use the money to buy servers, data output, boosters, and unlock upgrades.", nil, {
        context = "A description on what \"Money\" (a resource in-game) is usable for."}),
    CPS = loc("Compute Per Second", nil, {
        context = "CPS (Compute Per Second) is a measurement how fast server can process computation."}),
    CPS_DESCRIPTION = loc("This is how fast all your servers perform computation for its job. The win condition is to reach {b}1 billion{/b} CPS.", nil, {
        context = "A description on what \"CPS\" (Compute Per Second) is for."}),
    LOAD = loc("Load", nil, {
        context = "Think of \"load\" as the \"electricity load\""}),
    LOAD_DESCRIPTION = loc("\"Load\" measures how many servers, data output, and boosters can be in the datacenter. {c r=0.9 g=0.77 b=0.38}Exceeding the maximum load will impact the whole datacenter!{/c}", nil, {
        context = "A description on what does \"Load\" do."}),

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
    WIRE_RANGE = interp("Wire Range: %{range} Tiles", {
        context = "Denotes the maximum range of data output wire connection"}),
    WIRE_DPS = interp("Wire %{dps} {database}/second", {
        context = "Denotes the maximum range of data output wire connection"}),
    WIRE_COUNT = interp("Connections: %{count}/%{max}", {
        context = "Denotes the number of data that can be transmitted to single wire."}),
    JOB_QUEUE = interp("Tasks: %{job}", {
        context = "Denotes the number of additional tasks that can be queued."}),
    EFFECTIVITY = interp("Effectivity: %{effectivity}", {
        context = "Denotes the effectivity of a booster. The %{effectivity} is percentage of the booster efficiency."}),
    HEAT_TOLERANCE = interp("Heat Tolerance: %{min_heat}-%{max_heat}", {
        context = "Denotes the heat tolerance range of a machine."}),
    PRICE_TOOLTIP = interp("Price: %{price}{attach_money}", {
        context = "Denotes the price of an item."}),
    LOAD_TOOLTIP = interp("Load: %{load}{bolt}", {
        context = "How many load this item uses?"}),
    PROVIDE_LOAD_TOOLTIP = interp("Generates: %{load}{bolt}", {
        context = "How many load this item generates/provides?"}),
    TOTAL_LOAD_TOOLTIP = interp("Power Network: %{s}", {
        context = "How many load is used and power available across the whole power network? %{s} will be replaced by `load/total`."}),
    LEVEL_TOOLTIP = interp("Level: %{level}/%{maxLevel}", {
        context = "Denotes the level of an upgrade."}),

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
}
return text
