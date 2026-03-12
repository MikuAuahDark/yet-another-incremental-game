Plan out upgrades

TODO: Move this to GDD

Let's divide upgrades by multiple broad categories:
* Unlocks  
  Upgrades that unlock new things. Like new servers, data processors, and boosters. This is only for item unlocks.
* Efficiency
  Upgrades that improves overall performance on items.
* Job
  Upgrade that adds new and improves jobs. This includes new job, higher job frequency, higher price, etc.
* Misc.
  Upgrades that affect world sizes, job queue, max load, or anything that didn't fit in above category.

Now let's define how each subcategory are rendered:
* Unlocks
  * Rounded rectangle frame, color #43b4e8.
  * Add `{lock_open}` on top right, with themed outline.
  * The actual upgrade icon should be fit what it unlocks.
* Efficiency
  * Circle frame
  * For server heat reduction:
    * Blue color, #43b4e8
    * Add `{snowflake}` on top right, #d4feff, with black outline.
  * For load reduction:
    * Yellow, #ebd85e
    * Add `{bolt}-` on top right, colored green (as in "buff"), with themed outline.
  * For DPS improvements:
    * Kind of dark blue-purple, #828ecf
    * Add `{database}-` on top right, colored white, with black outline.
  * For CPS improvements:
    * Pink, #ed8ab8
    * Add `{dns}+` on top right, colored blue #43b4e8, with themed outline
* Job
  * Rhombus frame, Miku color #61d4b1
  * For job unlock, add `{lock_open}` on top right, with themed outline.
* Misc
  * Hexagon frame, lime color #c4d14d.
