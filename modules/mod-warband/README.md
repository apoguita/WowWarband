# mod-warband

The in-house server module for WoW Warband. Everything Warband-specific that
needs the server lives here: today the XP multiplier, follower catch-up
experience, follower gathering, bound gear moving inside the Warband, magic find
and gold find. The client panel in `addons/Warband` drives the runtime settings
through this module's `.warband` chat commands.

**Warband implements its features in-house.** A third-party module named anywhere
in the project docs is a research reference for how a behaviour works - never a
dependency, never installed, never staged in this tree. If a feature looks like an
existing module's feature, it is still written here.

The directory used to be called `mod-warband-unbound-loot`, after the first
feature it happened to carry. That feature is gone - it cleared the soulbound flag
from everything, which broke items that are meant to be bound - and the name no
longer refers to it.

## Feature status

| Feature | State | Source |
| --- | --- | --- |
| XP multiplier | Live and verified in game | `WarbandSettings.cpp`, `WarbandCommands.cpp` |
| Follower catch-up XP | Live and verified in game | `WarbandSettings.cpp`, `WarbandCommands.cpp` |
| Follower gathering | On-demand apply verified; automatic sync not yet verified | `WarbandGathering.cpp` |
| Bound gear inside the Warband | Built; not yet verified in game | `Item.cpp` (core), `WarbandTrading.cpp` |
| Magic find | Built; not yet verified in game | `WarbandMagicFind.cpp`, `WarbandCommands.cpp` |
| Gold find | Built; not yet verified in game | `WarbandGoldFind.cpp`, `WarbandCommands.cpp` |
| Trash auto-sell | Built; not yet verified in game | `WarbandTrashSell.cpp`, `WarbandCommands.cpp` |
| Auction house control | Built; not yet verified in game | `WarbandAuctionHouse.cpp`, `WarbandCommands.cpp` |
| Instances stop restocking | Built; not yet verified in game | `WarbandInstances.cpp`, `WarbandCommands.cpp` |

Keeping the two kinds of bot apart is what `WarbandPlayerRoles.h` is for:
`WarbandFollowerMaster()` returns a leader only for a bot piloted by a real
player, so the XP, catch-up, gathering and trading code never mistake the world's
random bots for Warband followers.

There is exactly **one in-house core change**, and it is deliberate: the item binding
policy. Everything else the module does is implemented with public core API and needs
no `src/` change at all.

## Entry point and build

`src/mod_warband.cpp` exposes `Addmod_warbandScripts()`. The loader generates
that name from the directory name (`modules/CMakeLists.txt` builds
`Add<directory, with dashes as underscores>Scripts()`), so renaming the directory
requires a CMake configure followed by a build, not just a rebuild.

Build approval is required before any configure or build, as described in
`doc/Warband-Implementation-Policy.md`. Everything else here is read and changed
at runtime, so tuning the features never needs a rebuild.

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
`Warband.XP.Rate = 3` those amounts become x3.30 and x9.00.

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

    Warband XP multiplier set to 3x
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
and an enchant that would bind it does not stop it either. The item itself is
untouched: it keeps its soulbound flag, so what the game displays about it stays
true. What changes is only who may take it. With it on, all of that reverts to the
ordinary rule.

This is the one place Warband changes the core rather than working around it, and the
reason is that a module cannot answer those two questions: the trade handler, the mail
handler, the auction house and the inventory transfer paths all ask the core directly,
and none of them has a script hook.

### The client half

The core cannot decide what the client already believes. The client greys out items it
thinks are bound, and it decides that from the same tradeable flag the game uses for
the two hour loot-trade window. `WarbandTrading.cpp` sets that flag on the bound items
a Warband member is carrying, so the trade window offers them the way it offers any
other item. It does nothing at all while binding is enforced, which is what keeps the
panel's toggle honest: the flag mirrors the rule, it never bypasses it.

The grant is transient by design. It is never written to `item_soulbound_trade_data`,
the core strips the flag again on the next login, and the next grant re-applies it. It
is scoped to one Warband - a leader and its own followers, or two followers of the
same leader - so the world's random bots never carry a granted item, and a player with
no party is left alone entirely.

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
thing, and unlike magic find there is no per-looter hook to hang a narrower rule on. Gold from
vendoring, quest rewards, mail and the auction house is a different path and stays untouched; quest
money has its own `Rate.RewardQuestMoney` and `Rate.RewardBonusMoney` in `worldserver.conf`.

Because the module owns the rate, its value wins over `Rate.Drop.Money` in `worldserver.conf`.

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

What it does **not** survive, deliberately, is an instance reset — the client's "Reset all
instances", a GM reset, or the daily reset hour. `InstanceMap::Reset()` flags the map as
reset-after-unload, and `InstanceMap::UnloadAll()` then deletes every respawn row. That is exactly
what a reset means, so nothing here fights it.

Scope: dungeons and raids only, and only creatures the party killed — a follower's kill counts, and
a summon's kill counts through its owner. Open-world respawns are untouched. `NeverAdjust` lists
take creature or map ids back out of the rule.

    .warband instance          reads the state, replies WARBAND_INSTANCE=enabled=1;kept=42
    .warband instance on|off   applies to the next death; already-dead creatures stay dead

The panel's Instances page has the same switch and the session's count.

## Auction house control

The market is not Warband code. `mod-ah-bot-plus` supplies it — it stocks the Alliance, Horde and
Neutral houses and buys what the party lists — and it has no user front end at all, which is what
this module adds: a control surface plus the panel page that talks to it.

    .warband ah                                   read the bot's live settings
    .warband ah seller | buyer on | off           switch a side of the market
    .warband ah items <10-5000>                   listings added per cycle
    .warband ah candidates <1-50>                 listings the buyer checks per cycle
    .warband ah stock <alliance|horde|neutral> <n>  stock target for one house
    .warband ah repopulate                        rebuild the bot's item lists and top up now

The reply is
`WARBAND_AHBOT=installed=1;seller=1;buyer=1;items=150;candidates=5;alliance=1200;horde=1200;neutral=200`,
and `WARBAND_AHBOT=installed=0` when the bot is not installed.

How a change lands: the bot reads its settings from `configs/modules/mod_ahbot.conf` in its own
`OnAfterConfigLoad`. A command here rewrites that one line in the file — comments and every other
option untouched — then reloads the configuration and re-runs the config hook, which is the path
`.reload config` takes. So the change is live without a restart, and the bot repopulates its item
candidate lists on the way. Prices, filters and listing rules are deliberately not exposed: they
belong to the bot's own file.

## Trash auto-sell

The bag-space fix, not an economy feature. A party of five loots five times as much grey junk, and
a follower's bags cannot be opened and emptied by hand the way the leader's can, so grey loot is
sold the moment it is picked up: the vendor price is paid to whoever looted it and the item is
destroyed before it can accumulate. Which purse the copper lands in is deliberately unimportant.

    .warband trash            read the state and the session totals
    .warband trash on | off   sell grey loot at pickup, or stop
    .warband trash sell       empty the party's bags of grey loot right now

The reply is `WARBAND_TRASHSELL=enabled=1;sold=12;copper=3456;swept=0`, and the panel's Trash sell
page shows the same numbers with a toggle and a sweep button.

It hangs on `PlayerScript::OnPlayerLootItem`, which the core raises at the end of the ordinary
pickup path (`Player.cpp:13954`, after `StoreNewItem` and `SendNewItem`) for every `Player` - the
real player and every follower alike. No core change is involved.

Never sold: quest-class items, items that start a quest, and anything an accepted quest still
needs. A grey with no vendor price is left in the bags rather than deleted for nothing. The
keep-grey-"upgrades" rule from the module that inspired this is not copied: for vendor trash it
never fires.

Why the sweep exists: a pickup only happens when the looting character has a free slot, so a bag
that is already full cannot be emptied by looting. `.warband trash sell` walks the leader's bags
and every follower's, which is the only way to clear a follower that filled up before the feature
was switched on.

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

