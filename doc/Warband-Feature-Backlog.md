# WoW Warband feature backlog

**Status:** working inventory for prioritisation  
**Last updated:** 16 October 2026

## Implementation rule

**Every feature in this list is implemented in-house by Warband.** Server behaviour
belongs in a Warband-owned AzerothCore module; a core change is made only where a module
cannot provide the hook; player-facing controls belong in the Warband client addon. This
is the rule set by [the implementation policy](Warband-Implementation-Policy.md).

**Third-party modules and addons are reference material only.** They are never
dependencies, never an install queue, and never part of the build. The research exists to
answer three questions about a capability we intend to build ourselves: what the behaviour
actually requires, what overlaps with something else, and which pitfalls were already hit.
Where a row below names a module, that is a research citation — the source of what we know
— not something to install. The candidate sources are not kept in `modules/`, which is
consistent with this rule.

Components that are already installed in the local runtime are the baseline, not Warband
features. They are listed separately below.

**States used in the tables**

| State | Meaning |
|---|---|
| **Live** | Built, loaded, and observed working in game |
| **Installed** | In place in the runtime, behaviour not yet checked in game |
| **Source only** | Warband's own code exists but has never been built or loaded |
| **Designed** | Direction recorded, nothing implemented |
| **Waiting** | Cannot start until a listed decision is made |
| **Deferred** | Recorded, deliberately not being built now |

## Runtime baseline (installed, not Warband features)

| Component | Role in the runtime |
|---|---|
| `mod-playerbots` fork | Supplies controllable followers; the pinned fork the build targets |
| `mod-ale` | Lua scripting path used by local scripts |
| `mod-multibot-bridge` | Server side of the MultiBot controls |
| `mod-progression` | Installed and configured at phase 18; supplies phase gating and its own rules |
| MultiBot and Playerbot Manager addons | Existing client-side companion controls |

## Warband features that are live and verified

| # | Feature | Built as |
|---|---|---|
| — | XP multiplier, 1x–10x, changeable live | Warband module: command, setting, `OnPlayerGiveXP` hook |
| — | Follower catch-up XP: a follower behind its leader earns more, on top of the global rate | Warband module: same hook, `PlayerbotAI::GetMaster()` to find the leader, config plus `.warband catchup` commands. Panel controls for step, floor, cap and on/off |
| — | Unrestricted race/class combinations: all 100 WotLK pairs, including Human Shaman and Undead Paladin | Warband-owned creation data: world SQL for creation, skills and starting spells; the server's `CharStartOutfit.dbc` for starting gear; the client's `CharBaseInfo.dbc` and `patch-z.mpq` for what the creation screen offers. Confirmed in game 16 October 2026 |
| — | Follower gathering: companions receive the leader's Herbalism, Mining and Skinning values and rank spells, so they work the same nodes and skin the same corpses | Warband module: raise-only mirror applied on leader login, on group join, and on `OnPlayerUpdateSkill` / `OnPlayerSetSkill`; `.warband gather` plus a panel page. On-demand apply confirmed in game 16 October 2026; the automatic update paths are built but not yet verified |
| — | Warband settings window: feature tree, detail pages, live server status, `/warband`, `/ww`, minimap icon | Warband client addon |
| — | Follower party that follows and fights | Runtime baseline |

## Installed in the runtime but never verified in game

No Warband code is involved; each is a test.

| # | Feature | What to check |
|---|---|---|
| — | All 11 primary professions (`MaxPrimaryTradeSkill = 11`) | Confirm after the next worldserver start |
| — | Playerbots quest synchronisation (`SyncQuestWithPlayer = 1`) | Follower completes when the leader turns in; reward behaviour |
| — | Progression configuration (phase 18, enforced rules, damage x0.6, healing x0.5) | Intended effect in play |
| — | `Progression.TradableBindsOnPickup.Enforced = 1` | What it actually permits. It is a baseline setting, not Warband's gear sharing, and it does not decide that work |

## Gaps in Warband's own work, found while checking the tree

1. **Resolved, 16 October 2026: binding is a core policy switch, not a cleared flag.** The
   binding-free feature that erased the soulbound flag from almost everything is gone; it
   contradicted binding itself. Gear sharing now lives where the core asks the question:
   `Item::CanBeTraded()` and `Item::IsBindedNotWith()` consult
   `WarbandIsItemBindingEnforced()` (`src/server/game/Entities/Item/Item.cpp`), defaulting to
   the ordinary rule and set from `Warband.Binding.Enforced`. This is Warband's one deliberate
   core change, and it exists because those two functions have no script hook.
2. **Resolved, 16 October 2026: the Warband module has a runtime config under its own
   name.** `conf/mod_warband.conf.dist` is installed as
   `bin/RelWithDebInfo/configs/modules/mod_warband.conf`, that file name is compiled
   into the server's config list, and all eight options are read from it. The rename
   from `mod-warband-unbound-loot` needed a CMake configure, which has been run; the
   pre-rename `mod_warband_unbound_loot.conf` and its `.dist` are now dead files that
   nothing reads.

## Feature backlog

### Party and progression

| # | Feature | Where we build it | State / waiting on |
|---|---|---|---|
| 1 | Follower catch-up XP: a recruit levels fast while behind the leader | Warband server module | **Live and verified** — `1 + 0.10 x levels behind` on top of the global rate; step, floor, cap and on/off are adjustable from the panel |
| 1a | Catch-up tuning: the last few levels are the slowest, and the 70-80 stretch costs more than everything before it | Warband server module | Open — `Warband.CatchUp.MinMultiplier` exists for the tail and is still at 1.0 |
| 1b | Catch-up scope: whether every experience source should receive the bonus, or only some | Warband server module | Open — currently kills, quests, exploration and battlegrounds all receive it |
| 2 | Party growth to five members, complete around level 15 | Warband server module + addon | Designed — waiting on cadence and eligibility |
| 3 | Recruitment flow: how a follower joins | Warband server module + addon | Waiting — no model selected |
| 4 | Leader-paced questing: leader does objectives, followers complete at turn-in | Warband server module | Designed — verify the baseline sync first |
| 5 | Follower reward delivery at turn-in | Warband server module | Waiting — direct reward or routed afterwards |
| 6 | Shared campaign progress for late recruits | Warband server module | Waiting — four documented models, none chosen |
| 7 | Companion quest state model | Warband server module | Waiting |
| 8 | Party management: bench, swaps, saved compositions | Warband server module + addon | Waiting |
| 9 | Five-member raid and world-event downscaling | Warband core + server module | Designed — largest item; research only rationale available |
| 10 | New feature pages in the window as the above land | Warband client addon | Designed — one page per feature |

### Items, loot and gear

| # | Feature | Where we build it | State / waiting on |
|---|---|---|---|
| 11 | Gear sharing inside the Warband: any bound piece moves to any companion | Warband core (binding policy) + server module + addon | **Built, not yet verified in game** — the core's own two questions (`Item::CanBeTraded`, `Item::IsBindedNotWith`) consult a Warband policy switch, so trade, mail, auction, guild bank and the inventory transfer all let a bound item through. The panel's Item binding page turns the ordinary rule back on; the item keeps its soulbound flag either way |
| 12 | Gear routing to the right follower | Warband server module + addon | Designed — waiting on the loot policy |
| 13 | Loot ownership default | Warband server module | Waiting |
| 14 | Auto-sell and protection rules for items | Warband server module | Waiting |
| 15 | Loot collection convenience for nearby corpses | Warband server module (+ client) | Designed |
| 16 | Companion equipment, talents and build control | Warband client addon + server module | Designed — equipment-first scope |
| 17 | Boss loot recovery | Warband server module | Deferred |
| 44 | Gold find: a multiplier on looted coin | Warband server module + addon | **Built, not yet verified in game** — the module owns the core `Rate.Drop.Money` and re-applies it on config load, so the panel can change it live. Default x3; covers creatures, chests, mines and containers, not vendoring or quest rewards |
| 43 | Magic find: better gear, not more gear | Warband server module + addon | **Built, not yet verified in game** — `GlobalScript::OnItemRoll` scales a row's chance by a per-quality multiplier, capped at a guaranteed drop. Shipped defaults x2 green, x4 blue, x6 purple/orange/gold. No rows added, no extra rolls, no extra items; poor and normal untouched; Warband loot only |

### Economy

| # | Feature | Where we build it | State / waiting on |
|---|---|---|---|
| 18 | Normal Auction House buying and selling | Warband server module | Designed — research shows two candidate approaches, neither adopted |
| 19 | Black Market Auction House | Warband server module + client UI | Deferred — recorded capability is bidding only, no player selling |
| 20 | Companion gold brought to the leader | Warband server module | Designed |
| 21 | Auction House client convenience | Warband client addon | Deferred |

### World and convenience

| # | Feature | Where we build it | State / waiting on |
|---|---|---|---|
| 22 | Gathering convenience for a solo party | Warband server module | **Live** — companions mirror the leader's gathering skills, raise-only. On-demand apply confirmed in game 16 October 2026; the automatic sync paths are built but not yet verified |
| 23 | Junk auto-sell | Warband server module | Designed |
| 24 | No creature respawns inside instances | Warband server module | Designed |
| 25 | Return to the dungeon entrance after death | Warband server module | Designed |
| 26 | Assisted dungeon mode led by a tank follower | Warband server module | Deferred — optional mode |
| 27 | Conventional raid bot support | Warband server module | Deferred — does not deliver five-member raids |
| 28 | Dual spec and remote talent reset | Warband server module | Deferred — preference |
| 29 | Hearthstone cooldown, flight path unlocking | Warband server module | Deferred — travel pacing preference |
| 30 | Warband camp services | Warband server module | Deferred |
| 31 | Account-wide shared systems | Warband server module | Deferred — research shows the studied approach skips bots, so it is not catch-up |
| 32 | Alternative XP and rate authorities | Warband server module | Deferred — research shows none implements leader-relative catch-up |
| 33 | Faster loot window | Warband client addon | Deferred |
| 34 | Quest planning or journal UI | Warband client addon | Deferred |

### Character and professions

| # | Feature | Where we build it | State / waiting on |
|---|---|---|---|
| 35 | Every race/class combination | Warband-owned creation data | **Live and verified**, 16 October 2026 |
| 36 | All 11 primary professions | Runtime configuration already installed | Installed — confirm after next start |

### Client panel

| # | Feature | Where we build it | State / waiting on |
|---|---|---|---|
| 37 | Feature tabs with live state instead of placeholders | Warband client addon | Partly live |
| 38 | Reset-to-default on the XP page | Warband client addon | Designed |
| 39 | Announce changes in chat | Warband client addon | Designed |
| 40 | Panel scale or size option | Warband client addon | Designed |
| 41 | Remembered selection and expansion | Warband client addon | Live |
| 42 | Window position memory, minimap icon, `/ww` | Warband client addon | Live |

## Decisions waiting, gathered in one place

1. Catch-up curve and cap, and which experience sources it applies to.
2. Catch-up trigger: automatic or player-controlled.
3. Recruitment: how a follower joins, and whether a bench exists.
4. Loot ownership policy and recipient choice.
5. Quest reward delivery: direct or routed by the leader.
6. Companion quest state model.
7. Party management model.
8. Settled: followers gather. Their Herbalism, Mining and Skinning values are mirrored from
   the leader, so they can work the same nodes without owning the crafting professions.
9. Settled: nothing unbinds. A bound item moves like any other while the binding policy is off,
   and the panel switch restores the ordinary rule when it is on.

## Explicitly out of scope

Recorded in the design and assessment documents as not fitting the current direction:
individual character progression that conflicts with shared campaign progress, AuctionSim
style economy simulation, LLM-driven bot chat, broad NPC convenience bundles,
automation-led dungeon clearing, quest loot duplication that multiplies item supply,
random-bot sync that excludes party bots, and open-world party scaling that raises
difficulty instead of downscaling for five members.
