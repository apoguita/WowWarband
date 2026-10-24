# mod-warband

The in-house server module for WoW Warband. Everything Warband-specific that
needs the server lives here: today the XP multiplier, follower catch-up
experience, follower gathering, bound gear moving inside the Warband, magic find,
gold find, the supplier prices, and the control surface for the open-world scaler.
The client panel in `addons/Warband` drives the runtime settings through this
module's `.warband` chat commands.

**Warband implements its features in-house.** A third-party module named anywhere
in the project docs is a research reference for how a behaviour works - never a
dependency, never installed, never staged in this tree. If a feature looks like an
existing module's feature, it is still written here.

The directory used to be called `mod-warband-unbound-loot`, after the first
feature it happened to carry. That feature is gone - it cleared the soulbound flag
from everything, which broke items that are meant to be bound - and the name no
longer refers to it.

## Settings are saved

Everything the panel can change is remembered across a restart. The mechanism is one table in the
world database, `warband_setting(setting VARCHAR(48) PRIMARY KEY, value DOUBLE)`, filled by
`WarbandPersistence.cpp`:

    WarbandSettingGet("goldfind.multiplier", <config default>)
    WarbandSettingSet("goldfind.multiplier", value)      // called by every setter

The rule is the same everywhere: **the configuration file supplies the default and a saved value
wins over it.** A switch flipped in the panel, a multiplier typed into the command, a reset button -
each writes its row the moment it changes, so the next startup reads it back. Deleting a row (or
pressing reset) returns that setting to what the shipped configuration says.

This covers the XP rate, follower catch-up (enabled, debug, per level, floor, cap), item binding,
follower gathering (mirror, automatic), magic find (one row per quality), gold find, trash sell,
instances, the hearthstone and pet switches, and the supplier multipliers and floor.

Three features keep their state differently, on purpose: **AoE loot**, **world scaling** and **world
bots** rewrite the option in the configuration file of the module that owns the behaviour
(`mod-aoe-loot`, `mod-zone-scaling`, `playerbots`), because that file is where those features read it
and a second copy in the Warband table would be a second thing to keep in step. They persist either
way.

The table is created on first use, so a world that has never run this module still works, and the
read happens on first access rather than at a particular startup hook, so no feature can load a
default just because its script ran early.

## Feature status

| Feature | State | Source |
| --- | --- | --- |
| XP multiplier | Live and verified in game | `WarbandSettings.cpp`, `WarbandCommands.cpp` |
| Follower catch-up XP | Live and verified in game | `WarbandSettings.cpp`, `WarbandCommands.cpp` |
| Follower gathering | On-demand apply verified; automatic sync not yet verified | `WarbandGathering.cpp` |
| Bound gear inside the Warband | Built; not yet verified in game | `Item.cpp` (core), `WarbandTrading.cpp` |
| Magic find | Built; not yet verified in game | `WarbandMagicFind.cpp`, `WarbandCommands.cpp` |
| Gold find | Built; not yet verified in game | `WarbandGoldFind.cpp`, `WarbandCommands.cpp` |
| Supplier prices | Built; not yet verified in game | `WarbandSuppliers.cpp`, `WarbandCommands.cpp` |
| Trash auto-sell | Built; not yet verified in game | `WarbandTrashSell.cpp`, `WarbandCommands.cpp` |
| Instances stop restocking | Built; not yet verified in game | `WarbandInstances.cpp`, `WarbandCommands.cpp` |
| The Dungeon Finder travels the party | Teleport verified in game, companions included; heroic and Random picks not yet checked | `WarbandDungeonFinder.cpp` |
| Complete destination list | Built; not yet verified in game - lists every dungeon, heroic and raid with an entrance, unfiltered | `WarbandDungeonFinder.h`, `WarbandCommands.cpp` |
| Hearthstone without cooldown | Built; not yet verified in game | `WarbandConvenience.cpp`, `WarbandCommands.cpp` |
| Pets always happy | Built; not yet verified in game | `WarbandConvenience.cpp`, `WarbandCommands.cpp` |
| World scaling control | Built; not yet verified in game | `WarbandWorldScale.cpp`, `WarbandCommands.cpp` |
| AoE loot control | Built; not yet verified in game | `WarbandAoeLoot.cpp`, `WarbandCommands.cpp` |
| Random world bots control | Built; not yet verified in game | `WarbandRandomBots.cpp`, `WarbandCommands.cpp` |
| Companion pays in a trade | Built; not yet verified in game | `WarbandTrading.cpp`, `WarbandTrade.h`, `WarbandCommands.cpp` |

Keeping the two kinds of bot apart is what `WarbandPlayerRoles.h` is for:
`WarbandFollowerMaster()` returns a leader only for a bot piloted by a real
player, so the XP, catch-up, gathering and trading code never mistake the world's
random bots for Warband followers.

There are **seven deliberate core changes**, and all are named here rather than hidden:

1. **Item binding** (`Item.cpp`): the module owns whether a bound item may move.
2. **Soul shards on any kill** (`src/server/scripts/Spells/spell_warlock.cpp`): Drain Soul and
   Shadowburn no longer require the dying target to yield experience or honor before granting a
   Soul Shard, and Drain Soul's per-tick shard chance follows the same rule. The retail rule starves
   a Warband that fights grey and low-level mobs, which is most of what it kills. There is no switch
   - the retail rule has no use on a five-character server.
3. **Soulstones never expire** (`src/server/game/Spells/SpellInfoCorrections.cpp`): all seven
   Soulstone Resurrection ranks replace the shipped 15-minute duration with the infinite entry the
   client data already contains, so a shard waits for the death it was made for instead of timing
   out. The buff is still consumed by the resurrection itself, so it pays out exactly once.
4. **Quest level follows the character** (`src/server/game/Entities/Creature/GossipDef.cpp`): the
   per-player quest-query packet sends the quest's level advanced to the highest
   `Warband.Quests.ScaleStep` multiple the viewer has reached, so a quest never slides into the gray
   band as the character levels (`Warband.Quests.ScaleStep = 0` restores the shipped level). The
   client draws the quest log's level, con colour and XP preview from that field; the Warband quest
   XP hook and the item-scaling quest-reward hook price the same way, so display and payout agree.
5. **Merchant payouts follow the gold multiplier** (`src/server/game/Handlers/ItemHandler.cpp`): what
   a player receives for selling an item to a vendor is its own value multiplied by the Warband gold
   multiplier - the same rate gold find pushes into `Rate.Drop.Money` for looted coin - so an item
   worth one gold pays five when gold find is 5. Buying is untouched: the shop charges the item's
   own value (see Supplier prices).
6. **Quest gold follows the gold multiplier** (`src/server/game/Entities/Player/PlayerQuest.cpp`): a
   positive quest money reward is multiplied by the same rate when it is paid, and the reward
   window's summary shows the multiplied amount. A quest that costs money keeps its cost.
7. **The item's shown sell price follows the gold multiplier** (`src/server/game/Handlers/ItemHandler.cpp`,
   item query response): the SellPrice the client draws its tooltip from is the item's value times
   the gold multiplier, so the number on the item matches what a merchant pays for it. The client
   caches item data per session, so a gold find change becomes visible in the tooltip after the item
   cache is refreshed; the payout itself is always live.

Everything else the module does is implemented with public core API and needs no `src/` change at
all.

## Entry point and build

`src/mod_warband.cpp` exposes `Addmod_warbandScripts()`. The loader generates
that name from the directory name (`modules/CMakeLists.txt` builds
`Add<directory, with dashes as underscores>Scripts()`), so renaming the directory
requires a CMake configure followed by a build, not just a rebuild.

Build approval is required before any configure or build, as described in
`doc/Warband-Implementation-Policy.md`. Everything else here is read and changed
at runtime, so tuning the features never needs a rebuild.

## Forked module submodules

Two modules the project depends on carry Warband changes, and both point at
Warband forks so the changes are public and a clone fetches them the ordinary way:

| Submodule | Fork | Branch | Warband change |
|---|---|---|---|
| `modules/mod-item-level-scaling` | `apoguita/mod-item-level-scaling` | `warband` | the `RequiredDisenchantSkill` int32 fix and quest reward item scaling (`ItemScaling.QuestRewards`) |
| `modules/mod-zone-scaling` | `apoguita/mod-zone-scaling` | `warband` | the group-level anchor for open-world scaling (`ZoneScaling.GroupAnchor`) |

Both forks branch off the upstream master they track, so the upstream history is
intact and the Warband commits sit on top of it. Nothing about these changes lives
only on a local checkout: `git submodule update --init` fetches the forks, and the
submodule pointers in this repository pin the Warband commits directly.

## XP multiplier

`Warband.XP.Rate` is a server-wide multiplier applied to every experience gain -
kills, quests, exploration and battlegrounds - for every character, followers
included. It must be a whole number from 1 to 10 and defaults to 3.

    .warband xp                 read the live multiplier, replies WARBAND_XP=<rate>
    .warband xp set <1-10>      apply a new rate immediately, replies the same way

Both commands are available at player permission level and do not need GM access.
Changes are runtime-only: a worldserver restart or `.reload config` restores the
value from the configuration file.

## Follower catch-up XP

A follower that is behind its leader earns extra experience, so a newly recruited
companion becomes useful without replaying the leader's history. The curve is
deliberately simple:

    catch-up multiplier = 1 + (Warband.CatchUp.PerLevel * levels behind)

A floor is applied afterwards and an optional cap last. The result multiplies the
already-multiplied experience, so at the shipped defaults a follower one level
behind gains 10% extra and one twenty levels behind gains 200% extra; at
`Warband.XP.Rate = 2` those amounts become x2.20 and x6.00.

It applies only to a bot piloted for a real player. The leader comes from
`PlayerbotAI::GetMaster()`, and a bot whose master has a headless session is left
alone, so the random bots that populate the world are never affected. Because
this is a Warband feature rather than a Playerbots one, Playerbots' own
`Playerbots.RandomBotXPRate` is untouched.

Both multipliers are applied in the same hook, `OnPlayerGiveXP`, which the core
calls before the amount is granted.

Configuration, all in `conf/mod_warband.conf.dist`:

| Option | Default | Meaning |
| --- | --- | --- |
| `Warband.XP.Rate` | 3 | Server-wide experience multiplier, whole numbers 1 to 10 |
| `Warband.CatchUp.Enabled` | 1 | Turn the catch-up bonus on or off |
| `Warband.CatchUp.PerLevel` | 0.10 | Extra experience per level of difference, 0 to 10 |
| `Warband.CatchUp.MinMultiplier` | 1.0 | Lowest multiplier while behind, 1 to 100 |
| `Warband.CatchUp.MaxMultiplier` | 0 | Upper limit, 0 for uncapped |
| `Warband.CatchUp.Debug` | 0 | Log each applied multiplier, at most once a second |

Out-of-range values are rejected at startup and on reload with an error log line,
and the default is used instead.

The values can be changed without a rebuild:

    .warband catchup                 read the current settings
    .warband catchup step <0-10>     extra experience per level behind
    .warband catchup floor <1-100>   lowest multiplier while behind
    .warband catchup cap <0-100>     highest multiplier, 0 for uncapped
    .warband catchup on | off        enable or disable

The reply is a single machine-readable line,
`WARBAND_CATCHUP=enabled=1;step=0.10;floor=1.00;cap=0.00;applied=0`, which the
addon reads to show live state on the XP Options tab. `applied` counts how many
times the bonus has been granted since the worldserver started, which makes the
feature verifiable without reading logs. At startup the worldserver logs the
active values, for example:

    Warband XP multiplier set to 2x
    Warband catch-up enabled: +0.1 per level behind, floor 1, cap uncapped

## Bound gear inside the Warband

Warband is a single-player party game: a bound item is bound to the party, not to one
character, so binding is not treated as a barrier to moving gear. That rule lives in
the **core**, because the core is what asks whether an item may move:

| Question | Function |
| --- | --- |
| May this item be moved at all? | `Item::CanBeTraded()` |
| May it move to this player? | `Item::IsBindedNotWith()` |

Both are in `src/server/game/Entities/Item/Item.cpp`, and both now consult
`WarbandIsItemBindingEnforced()`, declared in `Item.h` and defined in `Item.cpp`. It
defaults to the ordinary game rule, so a build without this module behaves exactly as
AzerothCore does; the module sets it from `Warband.Binding.Enforced` when it loads
its configuration.

With the restriction off - the Warband default - a soulbound item can be traded,
mailed, auctioned, put in a guild bank and handed to a companion like any other item,
and an enchant that would bind it does not stop it either. The server rule is only
half of it: the client refuses a soulbound item in the trade window before any
tradeable flag is considered, so the module also removes the soulbound bit from the
carried items while binding is off (see *The client half* below). What changes is who
may take the item; with the restriction on, the ordinary rule comes back.

This is the one place Warband changes the core rather than working around it, and the
reason is that a module cannot answer those two questions: the trade handler, the mail
handler, the auction house and the inventory transfer paths all ask the core directly,
and none of them has a script hook.

### The client half

The core cannot decide what the client already believes. The client greys out items it
thinks are bound, and it refuses a soulbound item in the trade window before the
tradeable flag is considered - that was verified in game on 18 October 2026, where a
soulbound item with both flags set was still refused. So `WarbandTrading.cpp` removes
the soulbound bit from the carried items while binding is unenforced: the client only
offers trade for items it thinks are unbound. It also sets the tradeable flag, which
keeps the mail, auction and trade-finalize paths in step with the same state. It does
nothing at all while binding is enforced, which is what keeps the
panel's toggle honest: the flag mirrors the rule, it never bypasses it.

The grant is transient by design. It is never written to `item_soulbound_trade_data`,
the core strips the flag again on the next login, and the next grant re-applies it. It
is not scoped to a party: the played character's carried items are granted at login and
when a piece arrives, and a trade window is granted on both sides the moment it opens,
so a bound piece can be handed to a follower, an alt outside the group or any other
character. That is deliberate - the Warband has no rule that needs a recipient - and
the only skip is random bots' constant loot, which never needs a grant because nobody
trades their own bound gear out of it.

### The toggle

    .warband binding            read whether binding is enforced
    .warband binding on | off   on is the ordinary rule, off is the Warband rule

The reply is `WARBAND_BINDING=enforced=0`. The panel's Item binding page states the
policy in words and flips it, and the toggle is runtime only, like the other Warband
settings: a worldserver restart or `.reload config` returns it to
`Warband.Binding.Enforced`.

## Magic find

Better gear, not more gear. This is the same mechanism the core already has as
`Rate.Drop.Item.*`, but scoped to the Warband and settable while playing: a multiplier on
the drop chance of the rows that drop an item of that quality.

    new chance = min(chance * multiplier, 100)

So `x4` turns a 20% blue into 80%, `x6` turns a 3% legendary into 18%, and a row whose
result passes 100% simply becomes a guaranteed drop. Nothing else changes - no rows added
or removed, no extra rolls, no extra items, no duplicates, no table edits, and poor and
normal are never touched, so the junk distribution stays exactly as the game ships it.

The hook is `GlobalScript::OnItemRoll`, which hands the row's chance over by reference
once per row per loot generation, for ungrouped and grouped rows alike (`LootMgr.cpp:315`
and `:1276`). It runs before the core's own `Rate.Drop.Item.*` multiplier, so the two
compose, and before the `>= 100` shortcut, so a multiplier can legitimately make a row
guaranteed. Scope is the Warband's own loot - the character being played and its followers
- so random bots keep the ordinary tables and the core rates stay as configured.

| Key | Quality | Default |
| --- | --- | --- |
| `green` | uncommon (2) | x2 |
| `blue` | rare (3) | x4 |
| `purple` | epic (4) | x6 |
| `orange` | legendary (5) | x6 |
| `gold` | artifact (6) | x6 |

    .warband magicfind                        read all five multipliers
    .warband magicfind <tier> <multiplier>   for example .warband magicfind blue 4
    .warband magicfind reset                  every multiplier back to x1

The reply is `WARBAND_MAGICFIND=green=2.00;blue=4.00;purple=6.00;orange=6.00;gold=6.00`. The
panel's Magic find page shows each multiplier, steps it in halves with minus and plus,
and prints a worked example that updates live ("a 3% drop becomes: green 6%, blue 12%,
purple 18% ..."). The values live in `Warband.MagicFind.*` and are runtime only, like the other
Warband settings.

Two shapes a multiplier cannot reach, because there is no chance number to multiply: rows
with `Chance = 0` inside a loot group, which the game picks from at random instead of
rolling (boss gear pools are often built this way), and reference rows, whose quality lives
on the rows inside the referenced table and which are multiplied normally.
## Gold find

The companion of magic find, and simpler. The core already multiplies looted coin by
`Rate.Drop.Money` inside `Loot::generateMoneyLoot` (`LootMgr.cpp:808`), which covers the money on
creatures, chests, mines and containers. This module owns that rate - it sets it at configuration
load and again on every reload - so the panel can change it while playing instead of editing
`worldserver.conf`.

    .warband goldfind                read the multiplier
    .warband goldfind <multiplier>   x1 to x20, for example .warband goldfind 3
    .warband goldfind reset          back to x1

The reply is `WARBAND_GOLDFIND=3.00`, the shipped default is x3, and the panel's Gold find page
shows the multiplier with minus/plus buttons and a worked example ("a 50 silver pile becomes 1.5
gold").

Scope, stated plainly: `Rate.Drop.Money` is a world rate, so it applies to every coin pile the loot
system generates rather than to the Warband alone. On this single-player server that is the same
thing, and unlike magic find there is no per-looter hook to hang a narrower rule on. What a
merchant pays for an item sold to it, the trash auto-sell payout and a quest's own gold reward use
the same rate, so every gold a sale or a quest produces follows this one number. Mail and the
auction house are different paths with their own rates and stay untouched.

Because the module owns the rate, its value wins over `Rate.Drop.Money` in `worldserver.conf`.

## Supplier prices

The auctioneers are now the buyer and seller interface: clicking one opens a category menu in place
of the auction house window, with unlimited stock and a price on everything. Glyphs stay in the
existing per-class lists, with minor glyphs included. Unclassified glyphs are grouped under Misc. **The auctioneer
creatures themselves are converted in place** â€” same entry, same name, same spawn point â€” by
changing their `npcflag` and `gossip_menu_id`; no new NPC is created for players to look at. The
data behind that menu (the tree, the vendor lists) is generated by `tools/warband-suppliers.py` and
applied as table rows. This section is what it charges and pays:

    merchant price = max(floor, original sell price * multiplier[quality])
    charge         = merchant price + material cost

`original sell price` is the item's own `item_template.SellPrice` as the game shipped it, which is
the number on the item tooltip - one gold for a Field Repair Bot. The shipped rule is 2 for poor,
**1 for normal** (a common item keeps its own value, so the bot stays at 1 gold), then 4 uncommon,
5 rare, 6 epic, 7 legendary, 8 artifact, 9 heirloom, all above a ten copper floor. That is the
merchant price: what a merchant pays for the item, and what the suppliers pay too. What they
**charge** is that price plus what the item's materials cost - an item worth 1 gold that takes 3
gold of materials is sold for 4. Materials are priced by the same rule themselves (a bolt of cloth
costs its own charge, raw cloth costs its merchant price), and stock with no recipe charges exactly
its merchant price. What a player receives for **selling an item to a merchant** is the merchant
price multiplied by the Warband gold multiplier (gold find), so an item worth 1 gold pays 5 when
gold find is 5.

    .warband price                          read the eight multipliers and the floor
    .warband price rare 6                   set one quality (colour names work too)
    .warband price floor 25                 the lowest price, in copper
    .warband price apply                    write the prices onto the items
    .warband price reset                    the shipped rule: 2/1/4/5/6/7/8/9 and 10 copper

**Why a price is written onto the item instead of being scaled when a player clicks.** The core
charges `item_template.BuyPrice` (`Player::BuyItemFromVendorSlot`) and pays
`item_template.SellPrice` (the sell handler), and the item's template is read once at startup. The
only price hook in that path, `OnPlayerGetReputationPriceDiscount`, is per vendor: it is asked once
per purchase with no idea which item is being priced, so it cannot carry one multiplier per quality,
and it cannot express a floor. The multiplier therefore has to become a number in `item_template`,
which is read at startup - so after **Apply prices** the new prices are visible after the
worldserver restarts. Nothing re-prices on its own: prices change only when someone presses Apply.

**Two tables, no compounding.** `warband_supplier_price` keeps each catalogue item's *original*
price, and every apply recomputes from it, so pressing Apply twice is the same as pressing it once
and `Reset to defaults` is exact. It also keeps the item's computed `material_cost` (0 when the item
has no recipe): the generator writes that column from the crafting recipes, the module only reads it
and adds it to the merchant price, so changing a multiplier moves the merchant price part only.
`warband_setting` keeps the live values, which is what the panel
and the command read back; the keys in `mod_warband.conf.dist` and `data/configs/modules/mod_warband.conf`
seed a value nothing has saved yet. Both tables are created by the module and by the generator,
whichever runs first.

The panel's Supplier prices page (in `addons/Warband`) drives the same values: a row per quality with
minus/plus buttons, the floor, Apply prices and Reset to defaults. The reply is
`WARBAND_SUPPLIER=poor=2.00;...;heirloom=9.00;floor=10;items=7350;current=1`, where `current` says
whether the item prices already match the values shown.

Only catalogue items are ever touched: a row exists in `warband_supplier_price` for every item the
suppliers stock, and the module's apply only writes the entries in that table.

## Hearthstone and pet happiness

Two timers a five-character Warband cannot keep by hand.

**Hearthstone.** Using the item starts a cooldown on spell 8690 and on 39937 (the TBC
"There's No Place Like Home" twin some clients use). With `Warband.Hearthstone.AlwaysReady` on, both
cooldowns are cleared the moment the hearthstone cast turns into a teleport, and once more on login,
so the item is always ready. The clear only happens when the hearthstone is what is being cast,
so portals and summons are untouched. Mechanism borrowed from `mod-no-hearthstone-cooldown`
(`.agents/reference`).

**Pets.** A hunter pet's happiness is the `POWER_HAPPINESS` power: three steps of
`HAPPINESS_LEVEL_SIZE` (333000 each), drained on a `PET_LOSE_HAPPINES_INTERVAL` (7.5 s) timer in
`Pet::LoseHappiness`, and knocked down a full step whenever the pet dies. Below one step the pet is
"unhappy" and takes a damage penalty in `StatSystem.cpp`. A follower cannot be told to feed its pet,
so in a Warband the pet slides into unhappy and stays there. With `Warband.Pets.AlwaysHappy` on,
`AllCreatureScript::OnAllCreatureUpdate` tops the power back up whenever it has drained â€” for every
hunter pet on the server, the leader's included.

    .warband hearthstone [on|off]   replies WARBAND_HEARTHSTONE=enabled=1;cleared=3
    .warband pets [on|off]          replies WARBAND_PETS=enabled=1

## Quest level scaling

Quests keep their original displayed level in NPC lists and the quest log. `Warband.Quests.ScaleStep`
(default 5, `0` disables scaling) controls quest XP and eligible equipment reward levels instead.
For example, a level-15 quest pays as level 20 once the character is 20-24, then as level 25 from
25, while the client continues to show the original quest level.

Two systems use the scale step:

- **Experience** — `PlayerScript::OnPlayerQuestComputeXP` reprices the award at the character's
  highest reached step using a ratio of `Quest::XPValue`'s arithmetic, so quest rates and auras
  already applied to the amount survive untouched. The zone module's per-zone quest pricing is off
  (`ZoneScaling.Xp.Quests = 0`) so the two cannot correct the same award twice.
- **Reward items** — `ItemScaling.QuestRewards` in `mod-item-level-scaling` grants a scaled variant
  of eligible equipment rewards at the character's highest reached step. Scaling is upward only and
  honours enabled qualities and exclusions; random-suffix, quest-starter and scripted rewards keep
  their original. The reward window still lists the original item, while the scaled variant is
  applied when the reward is granted.

## Instances stop restocking

A Warband fights through a dungeon slowly, and the base game keeps putting the cleared trash back.
With `Warband.Instances.NoRespawn` on, a creature that dies inside a dungeon or raid keeps its
death: `UnitScript::OnUnitDeath` pushes its respawn ten years out and calls `SaveRespawnTime()`, so
the dead state is a database row rather than a memory flag.

That choice matters, because it is what survives an **unload**. When the last player leaves an
instance the core starts a 30-minute timer (`Instance.UnloadDelay`) and then destroys the map; the
respawn rows stay behind and are read back by `Map::LoadRespawnTimes()` the next time the instance
is created. A server restart behaves the same way. So a cleared corridor is still cleared after a
coffee break, a logout, or a restart.

What it does **not** survive, deliberately, is an instance reset â€” the client's "Reset all
instances", a GM reset, or the daily reset hour. `InstanceMap::Reset()` flags the map as
reset-after-unload, and `InstanceMap::UnloadAll()` then deletes every respawn row. That is exactly
what a reset means, so nothing here fights it.

Scope: dungeons and raids only, and only creatures the party killed â€” a follower's kill counts, and
a summon's kill counts through its owner. Open-world respawns are untouched. `NeverAdjust` lists
take creature or map ids back out of the rule.

    .warband instance          reads the state, replies WARBAND_INSTANCE=enabled=1;kept=42
    .warband instance on|off   applies to the next death; already-dead creatures stay dead

The panel's Instances page has the same switch and the session's count.

## The Dungeon Finder travels the party

A five-character Warband has nobody to queue with, so the finder sits there and matches nobody. It
is also, already, a complete travel menu: the client draws the dungeon list, the server holds an
entrance for every dungeon in `lfg_dungeon_template`, and both sides know which dungeons a character
may enter. So a pick is answered with a teleport rather than a queue.

Select a dungeon in the finder and press Find Group: the whole party, companions included, is put at
that dungeon's entrance. The boxes work as they always did: specific dungeons, a Random Dungeon, a
heroic, or a raid.

| Pick | Where the party lands |
| --- | --- |
| a specific dungeon | that dungeon's entrance, in the difficulty its entry names |
| Random Dungeon | one dungeon from the pool that box stands for, minus the ones the finder would have refused this character |
| several boxes ticked | any of them, drawn at random, which is what queueing for several meant |
| a raid | the raid's entrance; the core still asks for a raid group first |

Nothing is queued, and no role check, proposal or deserter timer is created. The join is refused
inside `PlayerScript::OnPlayerCanJoinLfg`, the hook the core calls from `LFGMgr::JoinLfg` after the
packet has been parsed and before the queue is touched, so the teleport is the whole answer to the
click.

The retail rules are kept rather than bypassed. `Player::TeleportTo` still runs every check it runs
for any teleport - level, attunement, an instance's own requirements, the raid-group rule, the hourly
instance limit - and a refusal arrives in the game's own words. The destination is the finder's own
entrance row. A heroic pick sets the party's dungeon difficulty, and a raid pick its raid
difficulty, before the jump, so the entry chosen is the copy of the dungeon that is entered;
instance saves are keyed by map and difficulty, so no saved dungeon is reset on the way through.

Leaving is the retail way too: the entry point is recorded before the party jumps, so the instance's
exit portal puts everyone back where they came from.

Refused in the module's own words: a click while dead, while in combat, or from a battleground (the
finder never allowed queueing from one, and a teleport would be a way out of the match). A dungeon
the finder has no entrance for is left alone. The finder's own rule that only the party leader
queues is kept as well: a follower clicking Find Group is ignored, exactly as it would be for a
queue.

Each jump is logged:

    Warband dungeon finder: Apo travels to Utgarde Keep (map 574, 4 party member(s) follow)

For any of this to be reached the finder itself has to be switched on: `DungeonFinder.OptionsMask`
ships as `5`, which includes the dungeon finder. Setting it to `0` disables the whole window,
travel included.

### The complete destination list

The window is not the whole menu, and it cannot be made one. Its entries come from the client's own
`LFGDungeons.dbc`, which carries a level window per dungeon (Deadmines `15-25`, Stockades `55-65`, a
heroic Northrend entry `80-83`), and the client draws only the entries whose window contains the
character's level. At 80 no classic dungeon is drawn at all, and no packet the server can send adds
one back - the client's FrameXML (`Interface\FrameXML\LFGFrame.lua`) is the legacy
Looking-For-Group wizard only, so the Dungeon Finder frames are native client code.

So the list is the server's own:

    .warband travel          -> WARBAND_TRAVEL=<id>|<kind>|<difficulty>|<min>|<max>|<name>;...   (chunked)
                             -> WARBAND_TRAVEL=                                               (closes the list)
    .warband travel <id>     -> WARBAND_TRAVELGO=ok=1;id=574;name=Utgarde Keep
                             -> WARBAND_TRAVELGO=ok=0;id=574;reason=noentrance|dead|combat|battleground|refused

Every entry of type dungeon, heroic or raid that has an entrance is listed - the shipped data carries
64 dungeons, 35 raids and 32 heroics, and the only ones left out are those with no entrance at all -
with its level window kept as information rather than used as a filter. Nothing is hidden, greyed or
dropped: level, attunement, lock and gear score are reported by the core's own teleport at the moment
of travel, in the game's own words, exactly as a finder pick is.

`.warband travel <id>` and a finder pick go through the same path, so the party, the companions, the
entry's difficulty and the exit portal all behave identically. The client half is
`addons/Warband/DungeonTravel.lua`, which turns the Dungeon Finder window into the travel menu: a
black panel, one row per destination, a Travel button on each, and no queue view at all.

## Trash auto-sell

The bag-space fix, not an economy feature. A party of five loots five times as much grey junk, and
a follower's bags cannot be opened and emptied by hand the way the leader's can, so grey loot is
sold the moment it is picked up: the vendor price is paid into the leader's purse and the item is
destroyed before it can accumulate. The leader is the one purse the player can see, so the party's
junk money stays in one place instead of filling follower purses nobody can open.

The counters belong to one Warband: they are keyed by the leader's GUID and start again at zero
when the leader logs in, so the panel reports what this party's own sales paid - a random bot
looting somewhere else in the world can never inflate them.

    .warband trash            read the state and this Warband's totals
    .warband trash on | off   sell grey loot at pickup, or stop
    .warband trash sell       empty the party's bags of grey loot right now

The reply is `WARBAND_TRASHSELL=enabled=1;sold=12;copper=3456;swept=0`, and the panel's Trash sell
page shows the same numbers with a toggle and a sweep button.

It hangs on `PlayerScript::OnPlayerLootItem`, which the core raises at the end of the ordinary
pickup path (`Player.cpp:13954`, after `StoreNewItem` and `SendNewItem`) for every `Player` - the
real player and every follower alike. No core change is involved. The sweep pays the leader as
well, whichever member held the item.

Never sold: quest-class items, items that start a quest, and anything an accepted quest still
needs. A grey with no vendor price is left in the bags rather than deleted for nothing, and an
item whose price cannot be credited (gold cap) stays where it is instead of disappearing. The
keep-grey-"upgrades" rule from the module that inspired this is not copied: for vendor trash it
never fires.

Why the sweep exists: a pickup only happens when the looting character has a free slot, so a bag
that is already full cannot be emptied by looting. `.warband trash sell` walks the leader's bags
and every follower's, which is the only way to clear a follower that filled up before the feature
was switched on.

## World scaling control

The open world scaler is not Warband code either. `mod-zone-scaling` - an installed, pinned
dependency, the one module in the tree that can scale creatures outside instances - presents
open-world creatures, quest rewards and loot at each character's own level, inside the zones the
server opts in. It is pre-release upstream: treat the mechanism as sound but the experience as
unverified.

This module owns only the switch over it. The panel's World scaling page and `.warband worldscale`
flip the module's single `ZoneScaling.Enable` option; zones, bands, direction and everything else
stay in `mod_zone_scaling.conf`.

**Off by default, deliberately.** The module ships disabled (`ZoneScaling.Enable = 0`), and with
its own `DefaultBehaviour = "off"` an enabled module still changes nothing until a zone is added to
its zone list - so flipping the switch alone does not scale the world. That matches the recorded
decision to keep the open world unscaled unless asked. When the server is built without the
module, the page reports `installed=0` instead of pretending to offer a switch.

    .warband worldscale           read whether it is installed and enabled
    .warband worldscale on | off  flip the module's ZoneScaling.Enable

The reply is `WARBAND_WORLDSCALE=installed=1;enabled=0`. A change rewrites that one line in
`configs/modules/mod_zone_scaling.conf` and reloads the configuration - the same path
`.reload config` takes - so the module picks it up without a restart.

## AoE loot control

Area looting is not Warband code either. `mod-aoe-loot` - the third installed, pinned dependency -
merges every lootable corpse in range into the window opened on one corpse, items and gold alike,
so a cleared pack is emptied from one place. The module carries its own per-character
`.aoeloot on|off`; this surface owns the server-wide configuration and the trash auto-sell closes
the integration gap described below.

    .warband aoeloot                     read the whole configuration
    .warband aoeloot on | off            the master switch
    .warband aoeloot message on | off    announce the module on login
    .warband aoeloot group on | off      also merge inside a group
    .warband aoeloot range <5-100>       corpse search radius
    .warband aoeloot corpses <1-50>      corpses merged per window
    .warband aoeloot mail on | off       mail an item when the bags are full

The reply is
`WARBAND_AOELOOT=installed=1;enabled=0;message=1;group=1;mail=0;range=55.0;corpses=20`. **Off by
default**: the module ships enabled (`AOELoot.Enable = 1`), so the Warband runtime seeds its
configuration with 0 and the base game's one-corpse window stays the default. A change rewrites
that one line in `configs/modules/mod_aoe_loot.conf` - appending it when the shipped file has no
such line, which is the case for `AOELoot.MaxCorpses` - and reloads the configuration, so it lands
without a restart. When the server is built without the module, the page reports `installed=0`
instead of pretending to offer switches.

One integration is Warband's own: the module stores the item it takes from a merged window on its
own path, which does not raise `OnPlayerLootItem` that the trash auto-sell hangs on. So
`WarbandTrashSell` also hooks `OnPlayerAfterCreatureLoot` and sweeps the bags once after that store
while area looting is enabled - the grey is still sold to the leader's purse. With area looting
off, the hook does nothing and the ordinary pickup hook does all the work.

## Random world bots control

The bots that wander the world are logged in and out by the playerbots module itself: its
`Playerbots.RandomBotAutologin` switch gates the whole random-bot tick, and the population is the
manager's `bot_count` event, re-rolled inside `[Playerbots.MinRandomBots, Playerbots.MaxRandomBots]`.
They are ambience, not Warband, and on a single-player server a five-character party plays better
without them. This surface is the switch and the size, and nothing else:

    .warband randombots              read the state
    .warband randombots on | off     start or stop the population
    .warband randombots set <1-500>  pin how many stay online

The reply is `WARBAND_RANDOMBOTS=enabled=1;target=500;online=123`. Off logs out the bots online at
that moment through `PlayerbotHolder::LogoutPlayerBot`, the same path the module uses itself, and
stops new logins; a target collapses the manager's own `MinRandomBots`/`MaxRandomBots` range onto
itself, so every re-roll of `bot_count` lands on the target, and then logs out the excess. **The
Warband's own companions are never random bots** - `IsRandomBot()` tests the random-account list and
the manager's own set - so the switch cannot touch the party. A change is applied at once and also
written into `configs/modules/playerbots.conf` - the autologin switch and the two bounds, nothing
else - so the next startup holds the same state; playerbots reads those options in
`OnBeforeWorldInitialized`, which is why the written value takes effect at the next start rather
than immediately. `conf/mod_warband.conf.dist` documents the surface without adding a setting, since
the module owns no key for it.

## Companion pays in a trade

A companion can hand coin over only by filling its side of a trade window, and the bot gets there
through a whisper sequence (`t <amount>`, twice, the second time while the window is already open)
that nobody should have to remember. This surface does that one step from the server instead:

    .warband trade                     report the open trade
    .warband trade gold <amount>       put that much of the companion's money into the trade

The amount is compact money: `1s`, `50c`, `2g`, `1g20s5c`, or a bare number of copper. The replies
are `WARBAND_TRADE=open=1;partner=Tanko;purse=1240;inTrade=0` and
`WARBAND_TRADEGOLD=ok=1;partner=Tanko;amount=100;purse=1240`, or
`ok=0;reason=notrade|notcompanion|nofunds` when it cannot happen.

What it does is narrow: it reads the trade the player already has open and calls the core's own
`TradeData::SetMoney()` on the **companion's** side, so the purse check, the packet both clients need
to render the amount, and the coin movement on accept are all the core's ordinary trade path - no
Warband-only money movement. Only a bot (any Warband follower) or a character on the player's own
account can be asked to pay; a real player on another account never is. `WarbandTrade.h` carries the
small interface, `WarbandTrading.cpp` the implementation.

## Follower gathering

The leader keeps the crafting professions; followers only need to gather for the
party. When the mirror is on, every follower in the party receives the leader's
Herbalism, Mining and Skinning skill values, so it can work the same nodes and
skin the same corpses. Playerbots already harvests whenever a bot has the skill -
`LootAction.cpp` casts Mining, Herb Gathering and Skinning whenever
`PlayerbotAI::HasSkill()` says so, and a node's lock is checked against the skill
value - so the missing piece is exactly the skill values.

Only the three gathering skills are mirrored, and only those the leader actually
has: a follower never loses a skill because the leader lacks it. The mirror is a
**floor, never a ceiling** - it only ever raises a follower, so a party member
that was trained further, or that was the character the player logged in as in an
earlier session, keeps its own progress. Whoever is being played pushes their
values out to the rest; nobody is dragged back down for having been the follower
while someone else was the leader.

Recipes and
crafting professions are deliberately not copied. The leader is the crafter, and
copying every recipe to every follower would bloat their spell maps and update
packets for no benefit; a gathering profession has no recipes anyway. The rank
spells the leader knows are copied with the skill, because those are what the
client uses to display the profession tier and what the bot casts on a node.

Writes only happen to a follower standing on the leader's map, which is also the
map thread, so the module never touches a player another thread owns. The mirror
runs on four occasions:

| Occasion | Hook |
| --- | --- |
| Leader logs in | `PlayerScript::OnPlayerLogin` |
| A follower joins the group | `GroupScript::OnAddMember` |
| A gathering skill gains a point | `PlayerScript::OnPlayerUpdateSkill` |
| A skill is written wholesale | `PlayerScript::OnPlayerSetSkill` |

The join case is the trigger that matters most, since followers normally join
after the leader is already in the world. The last two are what keeps the party in
step mid game instead of only at recruitment: working a node or a corpse raises
the leader's skill a point at a time, and a trained rank, `.setskill` or an
unlearned profession writes it wholesale. Both run on the map thread of the
player whose skill changed, which is the same rule the writes already follow.

The two paths are deliberately not the same work: a plain gain can never teach a
new rank spell, so that path copies values only, and the spell copy stays on the
SetSkill path. `OnPlayerSetSkill` is also how the mirror writes to a follower, so
that hook ignores events coming from a follower - otherwise a mirror would trigger
another mirror.

Because the hooks fire for every skill in the game, both filter on the three
gathering skill ids before doing anything else. A follower that gains a point on
its own keeps that point: its own progress is never undone, and it is only raised
further if it is still behind its leader.

    .warband gather              apply the mirror now and report the result
    .warband gather status       report the state without applying it
    .warband gather on | off     enable or disable the mirror
    .warband gather auto on|off  apply automatically on login, on join and on skill change

The reply is a single machine-readable line:

    WARBAND_GATHER=enabled=1;automatic=1;herbalism=450;mining=450;skinning=0;updated=2;applied=7

`herbalism`, `mining` and `skinning` are the leader's own values, which are what
followers receive. `updated` counts the followers changed by that application and
`applied` counts follower writes since the worldserver started, so the feature is
verifiable in game without reading logs. `applied` grows while you play, by
whatever the automatic paths needed, which is the quickest way to see the mid-game
sync working.

| Option | Default | Meaning |
| --- | --- | --- |
| `Warband.Gather.Enabled` | 1 | Turn the mirror on or off; `.warband gather` still applies on demand |
| `Warband.Gather.Automatic` | 1 | Apply on leader login, on follower join and on every gathering skill change |

Because the skills are written to the follower's own character data, they persist
after the feature is disabled. Clearing them again is a deliberate act, not a side
effect of turning the mirror off.

The GM side of testing this - giving the leader a profession, proving a follower
received it, and checking that nobody is ever lowered - is written up in
`.agents/plans/warband-gathering/warband-gathering.TESTING.md`.


