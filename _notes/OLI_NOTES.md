
# (IMPORTANT NOTE: This file is meant to be read in VsCode plaintext, NOT in a markdown-reader.)




## DATACENTER INCREMENTAL:

incremental game.
Reuse catx11 tree.

- Build servers in a big grid, optimize for energy, wire-placement, cooling, etc.
- There is a big queue of "compute tasks". Tasks get auto-dispatched, and earn money when done.

grow the datacenter.




## Resources / Systems:
There are multiple "things" to juggle:
- Compute amount
- Cooling
- Data transfer
- Energy

Wires move data back to the "root".
there is a maximum flow rate of "data" through wires.
So if you place many servers close proximity; well, great! But you won't have enough wires to transmit.
Likewise, they'll overheat.




## Server grid:
This is essentially a "grid" where you can place servers/structures.
Keep it simple: 1 item per grid-slot.

- Basic compute-servers: (Use energy, compute)
- More advanced compute-servers: (Use energy, fast compute)
- Energy-efficient servers: (Use low energy, compute)
- Energy-greedy servers: (Use HIGH energy, fast compute)
- COOLING SYSTEM: (Cools nearby servers)
- WIRE RELAY: (Moves data from computers -> root)
- OVERCLOCKERS: (Increases power of nearby servers)
- DATA-COMPRESSERS: (compress data that flows through it. Doesn't stack)
- ENERGY-BOOSTER: (Gives more energy to nearby servers.)
etc etc. Do more planning.

## Building servers:
Oli: im not sure the best UX to build servers yet. Have a play around with ideas, im happy to provide my ideas.
- WHATEVER THE CASE; it should be easy to see what servers/infrastructure you have unlocked.
- maybe best to categorize them; (servers, cooling, data/relays, energy?)




## Tasks and Task-Queue:
```lua
Task = {
    money = 100, -- how much you earn from completion
    computeSize = 1000, -- compute requirement, (ie kinda like, how much processing required)
    outputData = 300, -- the amount of output-data.
}
```

The task-queue should be visible on the left-side.
The player should see the tasks coming in, and should easily see where the bottlenecks are.

(ie not enough tasks? Need more advertising -> go to upgrade-tree, get advertising upgrades )
(too many tasks? Need more compute -> improve servers / infra)




## Upgrade-Tree:
Use catx11 upgrade-tree.
Upgrades should consist of buffs to existing servers, BUT ALSO more unique things like unlocks.






## JUICE / VISUALS:
IDEAS FOR VISUALS, PLEASE READ THIS:
- When a task starts, the task should "fly off" the left sidebar, and "into" the server that processes it.
- Data flowing through wires should be visible. (IF BOTTLENECKED: Should show (!) sign, and have a tooltip explaining.)
- If energy is bottlenecked, some servers should be disabled. (Show tooltip: "(!) INSUFFICIENT ENERGY (!)")
- When a task is completed, the cash should "fly towards" the HUD, just like catx11.
- In upgrade-tree, Use same godrays/juice that catx11 uses
- (MAKE SURE TO ADD SHADOWS BELOW THE SERVERS. THIS IS VERY CRUCIAL.)

If you want more ideas, ask me.







