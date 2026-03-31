g.definePowerGenerator("basic_generator", "Generator", {
    color = objects.Color.GRAY,
    price = 100,
    power = 2,
    wireLength = 2,
})
g.PREUNLOCKED_ITEMS:add("basic_generator")

g.definePowerRelay("basic_relay", "Relay", {
    color = objects.Color.GRAY,
    price = 100,
    wireLength = 5,
})
g.PREUNLOCKED_ITEMS:add("basic_relay")
