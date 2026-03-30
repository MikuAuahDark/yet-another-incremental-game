-- Simple file containing list translation text
-- This is to ensure all translation text are in one place as possible.

---@class TEXTLIST
local text = {
    HORIZONTAL_LIST_SEPARATOR = loc(", ", nil, {
        context = "A separator symbol used to denote item list in single horizontal text"}),

    JOB_QUEUE_NUMBER = interp("Tasks: %{njobs}/%{maxjobs}", {
        context = "Used in place to list tasks, with specific maximum amount of queueable tasks"}),
    MONEY = loc("Money", nil, {
        context = "A resource"}),
    MONEY_DESCRIPTION = loc("Use the money to buy servers, data processors, boosters, and unlock upgrades.", nil, {
        context = "A description on what \"Money\" (a resource in-game) is usable for."}),
    CPS = loc("Compute Per Second", nil, {
        context = "CPS (Compute Per Second) is a measurement how fast server can process computation."}),
    CPS_DESCRIPTION = loc("This is how fast all your servers perform computation for its job. The win condition is to reach {b}1 billion{/b} CPS.", nil, {
        context = "A description on what \"CPS\" (Compute Per Second) is for."}),
    LOAD = loc("Load", nil, {
        context = "Think of \"load\" as the \"electricity load\""}),
    LOAD_DESCRIPTION = loc("\"Load\" measures how many servers, data processors, and boosters can be in the datacenter. {c r=0.9 g=0.77 b=0.38}Exceeding the maximum load will impact the whole datacenter!{/c}", nil, {
        context = "A description on what does \"Load\" do."}),

    CATEGORY_LIST = interp("Category: %{categories}", {
        context = "Denoting list of category, the ${categories} will be replaced with the actual list of items later"}),
    CATEGORY_SERVER = loc("Servers", nil, {
        context = "Denotes the category of server buildings"}),
    CATEGORY_DATA = loc("Data I/O", nil, {
        context = "Denotes the category of data input or data output buildings"}),
    CATEGORY_BOOSTER = loc("Boosters", nil, {
        context = "Denotes the category of booster buildings used to boost server performance"}),

    CPS_NUMBER = interp("%{cps} {dns}/second", {
        context = "CPS (Compute Per Second) is a measurement how fast server can process computation. {dns} reflects \"Compute\" icon in-game."}),
    SERVER_HEAT_NUMBER = interp("%{heat}/%{max_heat} Heat", {
        context = "Denotes heat of a machine."}),
    DPS_NUMBER = interp("%{dps} {database}/second", {
        context = "DPS (Data Per Second) is a measurement how fast data processor can process data. {database} reflects \"Data\" icon in-game."}),
    WIRE_RANGE = interp("Wire Range: %{range} Tiles", {
        context = "Denotes the maximum range of data processor wire connection"}),
    WIRE_COUNT = interp("Connections: %{s}", {
        context = "Denotes the number of servers connected to this data processor. The %{s} will be replaced with `current_connections` or `current_connections/max_connections` later in-game."}),
    MAX_WIRE_COUNT = interp("Max Connections: %{s}", {
        context = "Denotes the maximum number of servers that can be connected to this data processor."}),
    EFFECTIVITY = interp("Effectivity: %{effectivity}", {
        context = "Denotes the effectivity of a booster. The %{effectivity} is percentage of the booster efficiency."}),
    HEAT_TOLERANCE = interp("Heat Tolerance: %{min_heat}-%{max_heat}", {
        context = "Denotes the heat tolerance range of a machine."}),
    LOAD_TOOLTIP = interp("Load: %{load}{bolt}", {
        context = "How many load this item uses?"}),
}
return text
