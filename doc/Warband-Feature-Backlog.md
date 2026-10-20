# WoW Warband feature backlog

**Status:** working inventory for prioritisation
**Last updated:** 16 October 2026

## What belongs in this list

**Only features: capabilities the game does not have, for the Warband as a party.** A capability
that merely removes friction the base game or the client leaves in place is a fix, not a feature,
and does not get a row here — clicking six corpses, sorting a bag, freeing a travel timer or
remembering a window position are fixes. A party of five learning to function together, and a raid
tuned for five, are features.

**Every row names where it came from**: a request, a recorded decision, or a
[shortlist entry](Warband-Server-Module-Shortlist.md) studied for the behaviour. The shortlist is
the research that says what a capability requires; this list is what Warband intends to build.
Delivered features are documented in the [README](../README.md) and are not repeated here.

**Everything is implemented in-house by Warband.** Server behaviour belongs in a Warband-owned
AzerothCore module; a core change is made only where a module cannot provide the hook;
player-facing controls belong in the Warband client addon. Third-party modules and addons are
reference material only: never a dependency, never an install queue, never part of the build.
A shortlist link in the Origin column is a citation of where the behaviour was studied.

## Runtime baseline (installed, not Warband features)

| Component | Role in the runtime |
|---|---|
| `mod-playerbots` fork | Supplies controllable followers; the pinned fork the build targets |
| `mod-ale` | Lua scripting path used by local scripts |
| `mod-multibot-bridge` | Server side of the MultiBot controls |
| `mod-progression` | Installed and configured at phase 18; supplies phase gating and its own rules |
| `mod-zone-scaling` | Open-world per-player level scaling (pinned dependency, pre-release upstream); installed disabled and controlled only through the Warband panel's World scaling switch |
| `mod-aoe-loot` | Area looting: one loot window merges the nearby corpses (pinned dependency); installed disabled and controlled only through the Warband panel's AoE loot switch |
| MultiBot and Playerbot Manager addons | Existing client-side companion controls |

Delivered and verified separately, documented in the README: XP multiplier, follower catch-up,
follower gathering, gear sharing inside the Warband, magic find, gold find, the 100 race/class
combinations, the 11 primary professions, and trash auto-sell.

## Features wanted

### Party and campaign

| # | Feature | Origin | Where we build it | State |
|---|---|---|---|---|
| 2 | Party growth to five members: the leader and four followers | The premise: the player roleplays the whole five-member party | Warband server module + addon | Designed — cadence and eligibility undecided |
| 3 | Recruitment: how a follower joins the party | Same premise | Warband server module + addon | Waiting on decision 3 |
| 4 | Leader-paced questing: the leader does the objectives, followers complete at turn-in, and a late recruit inherits campaign progress | The premise, plus the research on quest-loot sharing | Warband server module | Designed — baseline quest sync must be verified first. Decision 5 (reward delivery) and 6 (quest-state model) sit inside this |
| 8 | Party management: saved compositions, bench and swaps | Followed from 2 | — | **Not wanted** — the Party tab (item 48) already invites and dismisses per character, and that is the whole need. A saved Warband, a bench and swaps were proposed on top of it and are not wanted |
| 9 | Five-member adaptation of raids and large world events | The premise: content for four followers, not a raid of twenty-five | `mod-autobalance` + `mod-item-level-scaling` (approved dependencies) | **Being built, 16 October 2026.** The rules, as stated: in a **dungeon**, being below its level changes nothing, and being more than a margin above it scales **mobs and loot** up; in a **raid**, the encounter is always scaled down to the party size and the loot stays as it is — unless the party is over level by that margin, in which case the raid scales **up** in difficulty and its loot scales **up in stats only** (same items, same quantity). Level scaling never runs downward anywhere |
| 48 | Party roster: choose which characters on the account come online and join the party, from a **Party tab on the Friends frame** | Requested 16 October 2026 — the per-character commands existed but there was no window to pick from, and the client has no party-management screen at all | `.warband party` (module) + Warband client addon | **Live** — verified in game 16 October 2026: the tab lists every character with level, class and online state, Invite brings one into the party, Dismiss uninvites and logs it out (`UninviteUnit` first, because Playerbots' logout never leaves the group) |

### Companion bags and gear

Accepted 16 October 2026: a companion strip on the bag frame and on the character sheet opens a
follower's inventory or character sheet in MultiBot, and that is enough for now. It is delivered,
so it is documented in the [addon README](../addons/Warband/README.md) rather than tracked here.
Two improvements are recorded for later, not as open work: a real bag grid instead of MultiBot's
list, and moving items directly between members.

Loot itself is not on this list: the game's mechanics stay as they are (see *Not wanted*).

### Economy and world

| # | Feature | Origin | Where we build it | State |
|---|---|---|---|---|
| 18 | Normal Auction House: buy useful items, list and sell eligible ones, so the party's loot actually moves | **Decision, 16 October 2026: not built in-house.** The market is too much to write, so the approved dependency `mod-ah-bot-plus` supplies it and Warband builds only the control surface. That is the one recorded exception to the in-house rule, and it is named here as the rule requires | `mod-ah-bot-plus` (dependency) + Warband addon panel | **Withdrawn and removed, 18 October 2026** — the dependency is no longer a submodule, `.warband ah` and the panel's Auction house page are gone, and the auction tables were emptied (see *What the auction bot cost* below). Nothing is staged in this tree. The need it served — a place to buy stock and get rid of loot — is met by item 54 instead |
| 19 | Black Market Auction House | Shortlist: [Black-Market-Auction-House][bmah] — bid-only as it stands | Warband server module + client UI | Waiting on: player listing and selling support |
| 24 | Instances stop restocking: a creature that dies inside an instance does not come back for the rest of the run | Shortlist: [mod-dead-means-dead][dead-means-dead], read in full — the mechanism is its, minus the multiplier model | Warband server module + addon panel | **Built, not yet verified in game** — `WarbandInstances.cpp`: `UnitScript::OnUnitDeath` pushes the respawn ten years out and saves it, so a cleared corridor survives an unload and a restart; an instance reset still restores everything. Dungeons and raids only, party kills only, with `NeverAdjust` lists. `.warband instance` and the panel's Instances page switch it live |
| 47 | Dying inside an instance returns the party to the dungeon's start, alive, instead of a graveyard release and a corpse run through cleared trash | Requested 16 October 2026; the mechanism was studied from `DungeonRespawn` in the shortlist | Warband server module | **Postponed, 16 October 2026** — the only reference is hacky: it hijacks the release teleport to cancel the graveyard move, resurrects outright at a stored anchor, and keeps a per-character row in a character-database table; the repository is archived. Revisit later; nothing else is designed around it |
| 51 | Open-world scaling switch: world creatures, quest rewards and loot at each character's own level, with a panel switch and a safe default | **Decision, 18 October 2026: not built in-house.** The only in-tree scalers (AutoBalance, item-level scaling) are instance-only, and upstream AutoBalance refuses base maps outright (open issue azerothcore/mod-autobalance#199), so `mod-zone-scaling` is installed as the pinned dependency and Warband builds only the control surface. That is the second recorded exception to the in-house rule, named here as the rule requires | `mod-zone-scaling` (dependency) + Warband addon panel | **Built, not yet verified in game** — `.warband worldscale [on\|off]` and the panel's World scaling page flip the module's `ZoneScaling.Enable`; zones, bands and direction stay in `mod_zone_scaling.conf`. **Default off**: the module ships disabled and, with its `DefaultBehaviour = "off"`, an enabled switch alone changes nothing until a zone is opted in. Missing module → `installed=0` |
| 52 | World bot population: switch the random bots that roam the world off entirely, or pin how many stay online | Requested 18 October 2026 — the random bots scattered across the world are not useful on a single-player server, and the population was not controllable at all | Warband server module + addon panel | **Built, not yet verified in game** — `WarbandRandomBots.cpp` flips the playerbots `RandomBotAutologin` switch and collapses its `MinRandomBots`/`MaxRandomBots` range onto the target so every re-roll of `bot_count` lands there, logging the excess out at once; the Warband's own followers are never random bots, so the party is untouchable. **Both choices are written into `modules/playerbots.conf`**, so the state survives a restart; `.warband randombots [on\|off\|set <1-500>]` and the panel's World bots page |
| 53 | Market prices: one deterministic price per item, adjustable per quality tier, with a sell calculator so posting is never a guess | Requested 18 October 2026 after the auction house proved thin and unreadable: an item's value had to be discoverable before posting, not discovered by paying deposits | Warband server module + addon panel | **Removed with the market, 18 October 2026** — `WarbandMarket.cpp` and the panel page went with the auction bot. The pricing rule itself survived and is now the supplier price control in item 54: `max(floor, original sell price x multiplier[quality])`, with the multipliers and the floor owned by the panel instead of hard-coded in a generator |
| 54 | Supplier merchants: at every auctioneer spot, one merchant with a category tree, unlimited stock of craftables and materials, buying anything at the same price | Requested 19 October 2026, in the owner's words: "we will add functionality on warband module to replace auction house representatives with merchants that provide unlimited quantity of craftable items as well as materials and reagents as well as buy every item i can sell at the same markup value of the formula". Followed by "we need to segment the merchandise, the merchants do not have a sort feature, categories need to be made ... everythign should have as much detail in sub categories as possible", and "were supossed to REPLACE the current auctioneers interface with ours, thats it" | Data generated by `tools/warband-suppliers.py`; `WarbandSuppliers.cpp`; Warband addon panel | **Data applied to the world, control surface built, not yet verified in game** — the auctioneers are **converted in place**, not replaced by a new NPC: same creature, same name, same spawn, with `npcflag` 129 and a shared `gossip_menu_id`, so a click opens a category menu instead of the auction house. One menu serves every city: Armor (by type, then slot), Weapons (by family, one- and two-handed kept apart), Containers (bags by kind), Materials and reagents, Consumables, Glyphs (by class), Gems (by colour), Recipes (by profession), Ammunition (arrows/bullets) and Keys and tools. The deepest level of every equipment category is the level range 1-10, 11-20, 21-30, 31-40, 41-50, 51-60, 61-70, 71-80, with an "Any level" list for items that have no requirement; everything else stays one list per kind. **83 menus, 434 lists, 7,350 items, and nothing in the catalogue is left out**, `maxcount = 0` so stock never runs out. Prices are `max(floor, original sell price x multiplier[quality])`, charged and paid, edited from the panel's Supplier prices page or `.warband price`, and written onto the items by **Apply** (the worldserver must restart to show them). The data ships as a pending world update, `data/sql/updates/pending_db_world/2026_10_19_00_warband_suppliers.sql`, which the server applies on its own at first start and which clears the rows it owns first, so re-running it is harmless. Revert: `data/sql/warband/revert_warband_suppliers.sql` |

## Parked convenience work (fixes, not features)

Kept so the decisions are not lost, but they are not goals and are not counted as features.

| # | Work | Why it is parked |
|---|---|---|
| 15 | Nearby-corpse loot collection | **Delivered, 18 October 2026** — the module was studied and rejected as surgery, so it is installed instead: `mod-aoe-loot` is the third recorded dependency, one loot window merges the nearby corpses (items and gold, respecting rolls and master loot, optional mail on full bags), and the Warband panel's AoE loot switch owns its enable option, **off by default**. The trash auto-sell sweeps the bags after an AoE store so the two features compose. It is still a fix, not a feature |

**Proximity gathering (item 45) was closed as not wanted on 16 October 2026.** It was never a
leader-only feature: it meant a node or skinnable corpse being worked *without walking to it and
without the cast* — removing the gathering loop rather than enabling it. Followers already gather
the ordinary way, with the walk, the animation and the loot window, because the skill mirror
(item 22) gives them the leader's Herbalism, Mining and Skinning. Automating that loop away is not
wanted, so nothing is left of the idea.

Other conveniences were studied and are deliberately **not** tracked as features: auto-sort,
one-key interact, quiet bot roll messages, a faster loot window, flight-path unlocking, dual spec
and remote talent reset, returning to the dungeon entrance after death, recovering lost boss loot,
and panel conveniences. Trash auto-sell was one of these and is already built.

**Two conveniences were promoted out of that list on 16 October 2026 and are built**, because a
five-character Warband cannot keep two of the game's timers by hand:

| # | Feature | State |
|---|---|---|
| 49 | Hearthstone without a cooldown: the item is ready again the moment it is used | **Built, not yet verified in game** — `WarbandConvenience.cpp`: the cooldown of spells 8690 and 39937 is cleared when the hearthstone cast turns into a teleport, and once on login. `.warband hearthstone [on\|off]`; reference: `mod-no-hearthstone-cooldown` |
| 50 | Every hunter pet stays at full happiness, follower pets included | **Built, not yet verified in game** — happiness is the `POWER_HAPPINESS` power, drained on a timer and knocked down a step on pet death; `AllCreatureScript::OnAllCreatureUpdate` tops it back up. `.warband pets [on\|off]` |

## Not requested, kept for a possible future

Nothing here was asked for. These came from a module existing, not from a need, and they are
recorded only so the research is not lost.

| Idea | Where it came from | What it would be |
|---|---|---|
| Warband camp (item 30, closed 16 October 2026) | [mod-warband-camp][warband-camp] — a module whose name happens to contain "Warband" | A personal campsite with 320+ scenery props, dynamic phasing, 3D building tools, service NPCs (bank, vendor, repairs, auctioneer, trainers), rested XP and instant logout inside the camp, and a Playerbots tie-in that gathers offline alts around the fire. A housing system in all but name. If a smaller version is ever wanted, the useful part is field services for the party and nothing else |

## Removed on request

**18 October 2026: the auction bot is removed from the runtime, and with it the Warband surface that
drove it.** `mod-ah-bot-plus` is no longer a submodule, and `.warband ah` / the panel's Auction house
page are gone. Item 18 (normal auction house) is therefore open again, to be solved a different way.

The same day, an in-house market was attempted: a price ladder with a sell calculator, a permanent
shelf of every craftable, material and recipe, and a five-minute buyer. The shelf filled the houses
correctly, but the worldserver crashed about three minutes after it started posting, repeatedly, and
the fault was never located. The whole attempt - bot, control surface, shelf, buyer and the price
page - was removed rather than shipped half working, and the auction tables were emptied of the
state it had created. The code is kept out of the tree at `.agents/plans/warband-market/` in case
the approach is revisited.

## Not wanted

| Item | Why |
|---|---|
| Loot ownership rules (item 13) | **Settled 16 October 2026: the game's own loot mechanics stand.** Rolling, need/greed and the group's loot method are left exactly as the client and the core define them. Removing the binding restriction was the whole loot change |
| Gear routing to a chosen follower (item 12) | The same decision as 13 — it would have meant overriding the loot mechanics |
| Companion gold routed to the leader (item 20) | Follower coin stays with the follower, the way follower bags do |
| Transmogrification (item 46) | Read on 16 October 2026: `mod-transmog` is a gossip NPC that records appearances per character and overrides item display for **players only** — nothing in it involves bots, and companions can never wear a look. A party that transmogs only itself is not worth the dependency; closed for that reason |
| Open-world party scaling ([mod-open-world-party-scaling][open-world-party-scaling]) | It raises difficulty for a party; Warband needs downscaling for five |
| Random-bot sync ([mod-rndbot-sync][rndbot-sync]) | It excludes a player's own party bots, so it cannot catch up a follower |
| Conventional raid-bot support | Teaches bots ordinary raids; it does not make an encounter fit five members |
| Assisted dungeon mode led by a tank follower | Shifts play from leading a party to supervising automation |
| Account-wide sharing and alternative rate authorities | They skip the Warband's followers or compete with the module's own rules; the catch-up family already covers the need |

## Decisions waiting

1. Catch-up shape: the tail of the curve (`Warband.CatchUp.MinMultiplier` is still 1.0) and which
   experience sources receive the bonus. Feature, already built; this is tuning.
2. Catch-up trigger: automatic or player-controlled.
3. Recruitment: how a follower joins, and whether a bench exists.
4. Settled, 16 October 2026: the game's loot mechanics stand. Nothing overrides who owns a drop,
   nothing routes gear to a chosen follower, and follower coin and bags stay with the follower.
5. Quest reward delivery at turn-in: direct, or routed by the leader afterwards.
6. Companion quest-state model: what a follower's quest log actually is.
7. Settled, 16 October 2026: party management is the Party tab and nothing more — invite and dismiss
   per character. A saved composition, a bench and one-click swaps are not wanted.
8. Auction House buying model and price rules; appearance scope for transmog; camp service list.
9. Settled: followers gather. Their Herbalism, Mining and Skinning values are mirrored from the
   leader, so they can work the same nodes without owning the crafting professions.
10. Settled: nothing unbinds. A bound item moves like any other while the binding policy is off,
    and the panel switch restores the ordinary rule when it is on.
11. Settled, 16 October 2026: nearby-corpse loot collection is postponed (item 15); proximity
    gathering (item 45) is **closed as not wanted** — followers gather the ordinary way, with the
    walk and the animation, and removing that loop is not needed. Trash auto-sell is built. None of
    the three is a feature.
12. Settled, 16 October 2026: the in-instance death respawn (item 47) is postponed as well, for the
    same reason as 15 — the only reference is too hacky to build on. The creature-respawn rule
    (item 24) is untouched by that and stays a wanted feature.
13. Settled, 16 October 2026: the companion strip on the bags and the character sheet is accepted as
    it is — it opens MultiBot's windows and that is enough for now. Two later improvements are
    recorded, not scheduled: a real bag grid instead of MultiBot's list, and moving items directly
    between members instead of through a manual trade.
14. Settled, 18 October 2026: the open world stays unscaled unless the panel's World scaling switch
    is turned on. `mod-zone-scaling` is installed as the pinned dependency so the switch has
    something behind it; with the module's own `DefaultBehaviour = "off"`, enabling the switch alone
    still changes nothing until a zone is opted in. The item 51 switch was requested explicitly for
    this shape — on-demand, off by default.
15. Settled, 18 October 2026: area looting is delivered by the installed `mod-aoe-loot` dependency
    (item 15, re-opened and delivered) rather than rebuilt in-house; the Warband panel's AoE loot
    switch owns the module's enable option and defaults it to off, and the trash auto-sell sweeps
    the bags after an AoE store so the two features compose. `mod-aoe-loot` ships enabled upstream,
    so the Warband runtime seeds its configuration with `AOELoot.Enable = 0`. The panel owns the
    whole module configuration — enable, login message, group looting, merge radius, corpse count
    and mail fallback — in one page; the module's own per-character `.aoeloot on|off` remains.
16. Settled, 18 October 2026: with binding off, the client tradeable grant is **not scoped to the
    Warband party** — a bound piece can be handed to a follower, an alt outside the group or any
    other character. The request was explicit: no mechanic may restrict trading items. The played
    character's carried items are granted at login and when a piece arrives, and a trade window
    grants both sides; random bots' loot is still skipped because they never offer bound gear of
    their own, which keeps the grant off their loot path. **Refinement, 18 October 2026:** the
    tradeable flag alone was not enough — the client still refused a soulbound item that carried
    both flags (verified in game with a Smooth Walking Staff). So while binding is off the module
    also removes the soulbound bit from carried items; the client offers trade for items it thinks
    are unbound, and the tooltip accordingly loses its Soulbound line. The panel switch still
    governs everything: binding on restores the ordinary rule.
17. Settled, 18 October 2026: the random bots that roam the world are not Warband's, and their
    population is controllable from the panel (item 52). The switch turns the whole population off,
    logging out the bots online at that moment, and the target pins how many stay online; both act
    on the playerbots module's own `Playerbots.RandomBotAutologin` flag and its
    `MinRandomBots`/`MaxRandomBots` population range, so nothing new is built and no follower is
    involved — a Warband companion is never a random bot and is never touched by the switch. The
    default, until it is touched, is the configured behaviour. **Refinement, 18 October 2026:** a
    runtime-only switch was not enough — the first build applied the change but a restart brought
    the configured population straight back, which is not "deactivated". So every change is also
    written into `modules/playerbots.conf` (the autologin switch and the two bounds, nothing else),
    and the state therefore survives a restart.

18. Settled, 18 October 2026: prices are one rule and one number, not a model. The rule is `merchant sell price x multiplier[quality]`, floored, with the multipliers a per-tier ladder the panel owns (seeded x2 grey, x3 white, x4 green, x5 blue, x6 epic, x7 legendary, x8 artifact, x9 heirloom; floor 10 copper). Crafting-cost pricing, reagent sums and market-feedback pricing were all rejected: they cannot be checked by hand before posting, which is the whole point. The same reference price is what the market charges and what it pays for a player's listing, so an item posted at its price sells; the auction house's own cut remains the only asymmetry. Item 53.

19. Settled, 19 October 2026: **every Warband setting is saved**, because a value changed in game
    was forgotten by the next restart — gold find set to x5 came back at x3. The values live in the
    world database in one table, `warband_setting(setting, value)`, written by every setter and read
    back on the next boot; the configuration file is the default and a saved value wins over it.
    Deleting a row, or pressing reset, returns that setting to the shipped default. Three features
    keep writing their owner module's configuration instead — AoE loot, world scaling and world bots
    — because that file is where those features read the value, and a second copy would be a second
    thing to keep in step. `WarbandSuppliers.cpp` uses the same table under a `supplier.` prefix, so
    the supplier prices and every switch share one mechanism.

20. Settled, 19 October 2026: **soul shards no longer require a target that yields experience or
    honor.** The owner's words: "warlock soulshards are created by channeling a spell on a mob that
    yields experience or honor, it does not from low level mobs, i need to remove that constraint,
    any kill can produce a soulshard not only the ones that give experience". The gate was not in the
    spell engine - it is two `isHonorOrXPTarget` checks in `src/server/scripts/Spells/
    spell_warlock.cpp`: one that cancels the death-granted shard (`PreventDefaultAction`) and one in
    Drain Soul's per-tick chance. Both are gone, and Shadowburn's identical refund check with them.
    This is the second named deviation from upstream behaviour, after the item binding policy;
    Curse of Doom's doomguard summon keeps its own check because it is not a shard.

## Explicitly out of scope

Individual character progression that conflicts with shared campaign progress, AuctionSim-style
economy simulation, LLM-driven bot chat, broad NPC convenience bundles, automation-led dungeon
clearing, quest loot duplication that multiplies item supply, random-bot sync that excludes party
bots, and open-world party scaling that raises difficulty instead of downscaling for five members.

[shared-loot]: https://github.com/maluramichael/mod-shared-loot
[quest-loot-party]: https://github.com/nexartgroup/mod-quest-loot-party
[bot-inventory-master]: https://github.com/TopHatMan/mod-bot-inventory-master
[shared-gold]: https://github.com/maluramichael/mod-shared-gold
[ah-bot]: https://github.com/azerothcore/mod-ah-bot
[ah-bot-plus]: https://github.com/NathanHandley/mod-ah-bot-plus
[bmah]: https://github.com/Youpeoples/Black-Market-Auction-House
[warband-camp]: https://github.com/Ildourol/mod-warband-camp
[transmog]: https://github.com/azerothcore/mod-transmog
[retail-transmog-plus]: https://github.com/buildthehomelab/wow-mod-retail-transmog-plus
[dead-means-dead]: https://github.com/kjack9/mod-dead-means-dead
[open-world-party-scaling]: https://github.com/Stefan2102/mod-open-world-party-scaling
[rndbot-sync]: https://github.com/Yuof/mod-rndbot-sync
