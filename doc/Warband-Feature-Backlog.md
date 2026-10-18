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
| 8 | Party management: bench, swaps, saved compositions | Follows from 2: a five-member party needs a way to change who is in it | Warband server module + addon | Waiting on decision 7 |
| 9 | Five-member adaptation of raids and large world events | The premise: content for four followers, not a raid of twenty-five | Warband core + server module | Designed — largest item; encounter rules and per-boss variation are open |

### Party loot and gear

| # | Feature | Origin | Where we build it | State |
|---|---|---|---|---|
| 13 | Loot ownership: who is entitled to ordinary drops | Shortlist: [mod-shared-loot][shared-loot] and [mod-quest-loot-party][quest-loot-party] both attack it | Warband server module | Waiting on decision 4 |
| 12 | Gear routing: an item goes to the follower it suits | Shortlist: [mod-quest-loot-party][quest-loot-party] personal mode, which duplicating loot does not solve | Warband server module + addon | Waiting on 13 |
| 16 | Companion bags and character sheet: see what each follower carries, its gear and its stats, from the windows the player already uses | Shortlist: [mod-bot-inventory-master][bot-inventory-master] — not used in the end, because MultiBot already carries the windows | Warband client addon (+ server module if item transfer is built) | **Partly built, pending another revision** — a companion strip on the bag frame and on the character sheet opens MultiBot's existing follower windows (click for bags, shift-click for the sheet, and the reverse). The next revision decides whether MultiBot's list view is good enough or a real bag grid is needed; item transfer between members is **not** built |
| 20 | Companion gold reaches the leader's purse | Shortlist: [mod-shared-gold][shared-gold] | Warband server module | Designed |

### Economy and world

| # | Feature | Origin | Where we build it | State |
|---|---|---|---|---|
| 18 | Normal Auction House: buy useful items, list and sell eligible ones, so the party's loot actually moves | **Decision, 16 October 2026: not built in-house.** The market is too much to write, so the approved dependency `mod-ah-bot-plus` supplies it and Warband builds only the control surface. That is the one recorded exception to the in-house rule, and it is named here as the rule requires | `mod-ah-bot-plus` (dependency) + Warband addon panel | **Installed and running** — the seller keeps Alliance, Horde and Neutral stocked, the buyer purchases player listings, and `.warband ah` plus the panel's Auction house page switch both sides. Open: player-side convenience, i.e. whether to add the retail-style auction window (shortlist) |
| 19 | Black Market Auction House | Shortlist: [Black-Market-Auction-House][bmah] — bid-only as it stands | Warband server module + client UI | Waiting on: player listing and selling support |
| 30 | Warband camp: a party facility with the services a five-member Warband needs | Shortlist: [mod-warband-camp][warband-camp] | Warband server module | Designed — scope of services undecided |
| 46 | Transmogrification: the party looks how the player wants | Shortlist: [mod-transmog][transmog] and [Retail Transmog Plus][retail-transmog-plus] | Warband server module + client UI | Waiting on decision: appearance only, or the collection game |
| 24 | Instances stop restocking: a creature that dies inside an instance does not come back for the rest of the run | Shortlist: [mod-dead-means-dead][dead-means-dead], read in full — the mechanism is its, minus the multiplier model | Warband server module + addon panel | **Built, not yet verified in game** — `WarbandInstances.cpp`: `UnitScript::OnUnitDeath` pushes the respawn ten years out and saves it, so a cleared corridor survives an unload and a restart; an instance reset still restores everything. Dungeons and raids only, party kills only, with `NeverAdjust` lists. `.warband instance` and the panel's Instances page switch it live |
| 47 | Dying inside an instance returns the party to the dungeon's start, alive, instead of a graveyard release and a corpse run through cleared trash | Requested 16 October 2026; the mechanism was studied from `DungeonRespawn` in the shortlist | Warband server module | **Postponed, 16 October 2026** — the only reference is hacky: it hijacks the release teleport to cancel the graveyard move, resurrects outright at a stored anchor, and keeps a per-character row in a character-database table; the repository is archived. Revisit later; nothing else is designed around it |

## Parked convenience work (fixes, not features)

Kept so the decisions are not lost, but they are not goals and are not counted as features.

| # | Work | Why it is parked |
|---|---|---|
| 15 | Nearby-corpse loot collection | Postponed 16 October 2026: the reference swallows every `CMSG_LOOT` and rewrites the loot table, too much surgery inside a pipeline still being tested. It is a fix for clicking each corpse |
| 45 | Proximity gathering | Deferred 16 October 2026 until the loot pipeline has been played enough to judge. It is a fix for walking to each node; followers already gather the ordinary way |

Other conveniences were studied and are deliberately **not** tracked as features: auto-sort,
one-key interact, quiet bot roll messages, a faster loot window, no hearthstone cooldown,
flight-path unlocking, dual spec and remote talent reset, returning to the dungeon entrance after
death, recovering lost boss loot, and panel conveniences. Trash auto-sell was one of these and is
already built.

## Not wanted

| Item | Why |
|---|---|
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
4. Loot ownership policy: who owns ordinary drops, and which recipient rule applies.
5. Quest reward delivery at turn-in: direct, or routed by the leader afterwards.
6. Companion quest-state model: what a follower's quest log actually is.
7. Party management model: bench, swaps, saved compositions.
8. Auction House buying model and price rules; appearance scope for transmog; camp service list.
9. Settled: followers gather. Their Herbalism, Mining and Skinning values are mirrored from the
   leader, so they can work the same nodes without owning the crafting professions.
10. Settled: nothing unbinds. A bound item moves like any other while the binding policy is off,
    and the panel switch restores the ordinary rule when it is on.
11. Settled, 16 October 2026: nearby-corpse loot collection is postponed (item 15) and proximity
    gathering deferred (item 45); trash auto-sell is built. None of the three is a feature.
12. Settled, 16 October 2026: the in-instance death respawn (item 47) is postponed as well, for the
    same reason as 15 — the only reference is too hacky to build on. The creature-respawn rule
    (item 24) is untouched by that and stays a wanted feature.
13. Pending another revision, 16 October 2026: the companion-strip access (item 16) and the
    draggable windows work well enough to use and not well enough to keep. Two questions carry into
    the next pass: whether a follower's inventory needs a real bag grid instead of MultiBot's list,
    and whether items should move between members directly rather than through a manual trade.

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
