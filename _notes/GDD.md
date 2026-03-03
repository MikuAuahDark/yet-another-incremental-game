Make a Datacenter
=====

A short incremental game where you build datacenter. Process jobs with servers, think of their placement, solve
challenging cooling solutions, electricity constraints, and data transfer logistics!

There are many ways to finish the game.

Summary
-----

### Gameplay Loop

Player will focus on targetting to process as many compute job as possible by strategically placing servers while
considering other constraints.

The general gameloop would be as follows:
1. Buy server
2. Wire server to data processor
3. Server process jobs
4. Gain money after job is processed
5. Unlock upgrades or buy more servers.

The game is considered "finished" once player reaches 1 billion CPS (Compute Per Second) on average.

### Target Audience

The target audience will be players who love incremental games with strategy flavor on it.

Main target platform would be primarily PC (Steam) running Windows. We can do these platform if there's demand:
* Linux
* Android

Unfortunately we cannot do macOS and iOS due to lack of Mac.

### Unique Selling Point

This combines strategy and incremental game.
* Unlike Cookie Clicker, the player can use strategical placement of server to boost the CPS further (minmaxxing)
* Unlike generic strategy game, there are no lose condition so suitable for relaxing playthrough.

The main saitsfaction is seeing many servers crunching jobs, reaching higher and higher CPS.

World
-----

The world is gray tiles which player can place servers or other peripherals on.
We could use other skins for the tiles but for now let's stick with gray.

World has size of 101x101 (subject to change, world dimension must be odd though)

### Tiles

Each tile has "Heat" property. Servers and other peripherals alters the tile heat.

Tile can only occupied by one item.

Mechanics
-----

### Compute Job

Compute job is the main source of income in the game. Each compute job has the following property:
* `money` (number) - How many money is given once completed?
* `computePower` (number) - How much compute power is required to finish this job?
* `outputData` (number) - How much data it sends while the job is being processed?
* `category` (string) - Which kind of server is needed to process this job? For example, "ai" means this requires AI
  servers to process.

The speed of the actual processing depends on lowest demonimator on these 2 factors:
* Server CPS capability. If the wire has less data going through it, then the limiting factor is server CPS.
* Data Processor DPS capability. If the server CPS is huge but the data transfer is clogged, then the server is not
  fully utilized.

### Servers

Servers are the main building used to process compute jobs.

Servers has list of types of jobs it can process. Examples:
* General server has CPU. This means it can process any compute job with "general" `category`.
* GPU server has GPU. This means it can process compute job in "video" `category`.
* AI server has AI accelerator. This means it can process compute jobs in "ai" `category`.

To give more perspective, each server has the following property:
* `price` (number) - The server price to buy.
* `computePerSecond` (number) - How much compute it can process per second.
* `computePreference` (string[]) - List of compute job preference. First item has highest priority to be picked.
* `load` (number) - How much electricity load it needs.
* `heatTolerance` ([number, number]) - Heat tolerance range of the servers (min and max value respectively). If the
  server heat is below the minimum value, the performance is boosted depending on low it is. If the server heat
  exceeded the maximum value, the performance is reduced depending on how far it exceeded it.
* `heat` (number) - Amount of heat the server radiates on its tile.
* `heatRadiate` (integer) - Amount of additional heat radiated by the server to the adjacent tiles. This number is the
  iteration count of the spread. 0 means heat is localized.
* `heatRadiateAlgorithm` (string) - Heat radiate algorithm. Can be "taxicab" for Manhattan spread (diamond/rhombus
  pattern) or "chessboard" for Chebyshev distance.

The types of servers will be decided later.

Server must be wired to a single data processor to function. If server is not wired, the server will be marked with
triangle red X symbol on top of it.

Server also has performance metric that depends on their heat tolerance, overall datacenter load, and data throughput.
If the server has metric performance of less than 1, server will be marked with ⚠️ symbol.

### Data Processor

Data processor consolidates data from the servers to be sent to final destination. This acts as the logistics part of
the data. However, data processors can only receive so much data from the servers. This is called DPS (Data Per Second)

Data processor have these properties:
* `price` (number) - The booster price to buy.
* `load` (number) - How much electricity load it needs.
* `dataPerSecond` (number) - How much data it can consolidates per second.
* `wireLength` (number) - How long wires can be reach to servers in tiles, using Chebyshev distance.
* `wireCount` (number|nil) - How many wires it can connect to servers, or nil if unlimited.

### Boosters

These items provides buffs to the servers.

Boosters can:
* Reduce tile heat.
* Boost server performance.
* Make server efficient.
* Boost data processor DPS.

Boosters have these properties:
* `price` (number) - The booster price to buy.
* `load` (number) - How much electricity load it needs.
* `radiate` (integer) - Amount of additional tiles to affect. This number is the iterationcount of the spread. This
  cannot be 0.
* `radiateAlgorithm` (string) - Radiate algorithm. Can be "taxicab" for Manhattan spread (diamond/rhombus pattern) or
  "chessboard" for Chebyshev distance.

### Load

Each item has amount of load. The whole datacenter has specific amount of load.

If the total items load exceeding the whole datacenter load, the whole overall performance of the datacenter slows
down. This includes:
* Data Transfer has less DPS
* Booster has less effectiveness
* Server has less processing power

### Technologies

The equivalent of upgrade trees in common incremental games.

Upgrades ranging as follows:
* Opens new server types
* Improve server stats
* Improve data processor stats
* Improve booster stats
* Unlock more area


### UI/UX

#### Placement

Rough idea of UI is as follows:
* Top is the stats, like player money, the load, total CPS, and a pause button. Should be just simple strip. Each stat should
  have tooltip.
* Left is the job queue overview. For UX reasons, only ones that can fit shown there.
* Bottom is list of items that you can place, along with their price.
* Right is to alternate between the world or the upgrade tree.
* The rest is the server world.

#### Stats

Top area is the stats.

The left side contains:
* Money: ${a}/{b} indicates money player has.
* Load: ⚡{a}/{b} indicates overall load of the datacenter.
* CPS: 🖥{a}/s indicates average CPS of the datacenter.

The right side contains:
* Hide button toggle (hides the job queue and building list).
* Pause button.

#### Job Queue

Left side contains job queues. Job queue is a card showing these information:
* Name of the job queue
* Workload type (General, Video, AI, etc.)
* Compute required
* Data transferred
* Money earned

It also shows how many jobs in it and limit on how many jobs can be in queue.

For UX reasons, it only shows job queues that fits the container.

#### Item List

Bottom part contains item list.

Item list is categorized into 3 tabs: Servers, Data Processors, and Boosters.

Each category will show the respective items in that particular category.

Hovering or clicking shows the item information. Hold-pressing it will allow player to place it in the world by
dragging the item and dropping it on highlighted tiles, if player has enough money. Player can cancel placement by
dropping the item back to item list.

#### Tab Switch

Just a simple tab switch between dataenter and the technology tree.

#### World

* Player can pan the world by left click.
* Player can show item info by hovering on it.
* Player can also show the info by clicking on it, which makes it sticky until there's another mouse press again.
* To move item, player needs to hold-click the desired item on world.
  * To move it to other place, simply drag it to new tile.
  * To remove it, drag it to item list.

Glossary
-----

* Servers - Items that process compute jobs.
* Compute Jobs - An equivalent of "task" that needs to be processed by servers to earn money.
* CPS - Compute Per Second. How many computation is done by server.
* DPS - Data Per Second. How many data is transferred by the server to data processors.
* Items - Things that can be placed on the world grid. This includes servers, boosters, relays.
* Boosters - Items that improve overall performance of the servers or data processors.
* Data Processors - Items that collect data from the servers and send it outside the datacenters.
