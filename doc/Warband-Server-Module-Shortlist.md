# Warband server-module shortlist

This file is retained research, not an installation or build queue. Candidate
modules are independent components, not generic APIs. Use the findings as
references when defining Warband-owned server-module and client-addon/plugin
work. A third-party component becomes a *dependency* only through a recorded
decision that names it and says why Warband's own build does not supply the
behaviour. Any build requires a scoped estimate and the user's explicit approval
under the [implementation policy](Warband-Implementation-Policy.md).

**Warband implements these features in-house unless a recorded decision says
otherwise.** Every row below is a citation: the link records where a behaviour
was studied, not something to install. No candidate source is present in this
checkout, no candidate is a submodule, and none is configured or built. The
three read line by line are kept as read-only clones under `.agents/reference/`,
which nothing builds, configures, or loads.

Earlier versions of this file labelled rows "source staged", "pinned in this
repository" or "not staged". That wording was stale — no candidate source has
ever been staged here — and is retired. The presence-related statuses now read:

| Status | Meaning |
|---|---|
| Reference only | Upstream source or README was read for research; nothing from it is in the build |
| Reference only; not taken up | Same, nothing pending; the row records a finding, not a plan |
| Reference only; candidate for backlog item N | The behaviour is being specified as Warband's own build |
| Local copy under `extras/` | Source sits in this tree, deliberately inactive and uncompiled |
| Runtime baseline | Installed and compiled; a starting point, not a candidate |

Other wording in the status column — "promising candidate", "reference for later",
"convenience candidate" — judges the upstream code. None of it implies staging,
adoption or a dependency.

`mod-warband` is project-owned code, not a catalogue candidate. Its gear sharing is the one
Warband feature with a core change: `Item::CanBeTraded()` and `Item::IsBindedNotWith()` consult
a binding policy that the module sets from `Warband.Binding.Enforced` and the panel toggles.
Binding itself is left alone, and the module is compiled into the current build; its trading
behaviour still needs an in-game verification pass.

## Requested foundation

| Item | Status for evaluation | What it contributes | Important boundary |
|---|---|---|---|
| [mod-auto-gather][auto-gather] | Reference only; not taken up (closed 16 October 2026) | Automatic nearby herbs, ore, and skinning — harvesting without walking to the node or casting. | Closed with backlog item 45: followers already gather the ordinary way because the skill mirror gives them the leader's Herbalism, Mining and Skinning, and removing that loop is not wanted. Its player update hook does not exclude Playerbots either, which would have needed a decision of its own. The source stays under `.agents/reference/mod-auto-gather/` as study material only. |
| [mod-arac][arac] | Local data integration applied; gameplay verification pending | All WotLK race/class combinations, including Human Shaman and Undead Paladin. | World SQL applied; server DBC files replaced with a reversible backup under ignored `var/backups/`; client patch added as `patch-z.mpq`, preserving the existing `patch-a.mpq`. The database has 100 race/class combinations. No C++ build was needed; verify client patch loading and character creation in-game. |
| [mod-dead-means-dead][dead-means-dead] | Reference only; candidate for backlog item 24 | Prevents creature respawns in dungeons and raids by default; can customize creature respawn times. | Separate from the death-recovery task (47): this one is a respawn timer, that one is geography. Its README warns that an instance unload can restore normal respawn timing, which is why the Warband build must re-apply the switch on instance load; do not change `Instance.UnloadDelay` without separate review. |
| [DungeonRespawn][dungeon-respawn] | Reference only; postponed 16 October 2026 (backlog item 47) | A death inside a dungeon or raid returns the player to the point where they entered that instance, resurrected instead of released. | Read 16 October 2026 and judged hacky: `OnPlayerReleasedGhost` queues the player, `OnBeforeTeleport` cancels the graveyard teleport and revives them at a remembered entry position; the anchor lives in a per-character `dungeonrespawn_playerinfo` row. Config: `Enable` (default off), `RespawnHealthPct` (default 50). Repository archived in 2025. Kept as the record of what the behaviour needs, not as something to build on for now. |

## Loot, equipment, and follower housekeeping

| Item | Status for evaluation | What it contributes | Overlap / question |
|---|---|---|---|
| [mod-aoe-loot][aoe-loot] | Reference only; postponed 16 October 2026 (backlog item 15) | One loot interaction collects nearby corpses. | Collection only; it does not decide the equipment recipient. Read 16 October 2026 and judged too invasive for the loot pipeline still under test: it needs no core change (`ServerScript::CanPacketReceive` on `CMSG_LOOT`), but it swallows every loot-open packet, rewrites the opened corpse's row list, moves quest items straight into the bags and mails overflow. Its `module_string` SQL is unnecessary for a Warband build either way. |
| [mod-quest-loot-party][quest-loot-party] | Reference only; experimental fork, not taken up | Optional sharing of quest-objective items to party members who have and still need the quest, forced quest-item drops, or same-loot personal drops. | The fork says its hooks are already in AzerothCore, but it does not handle leader-only quest turn-ins or role-aware gear assignment. Personal drops duplicate eligible items to every group member and can multiply bag pressure and item supply. Experimental; review before considering. |
| [mod-shared-loot][shared-loot] | Reference only; not taken up | Removes need/greed/round-robin prompts by forcing Free-For-All. | A loot-method change, and Warband keeps the game's own loot mechanics (decided 16 October 2026): nothing overrides who owns a drop. |
| [mod-shared-gold][shared-gold] | Reference only; not taken up | Routes defined owned-Playerbot gold sources to the leader. | Follower coin stays with the follower in Warband (decided 16 October 2026), the way follower bags do. It also does not route Auction House proceeds. |
| [mod-bot-inventory-master][bot-inventory-master] | Reference only (server module and bundled client UI); candidate for backlog item 16 | Online same-account equipment commands plus a bundled 3.3.5 UI with equipment, individual bags, and party-bag cleanup views. | The UI is broader than Warband's equipment-first player-facing scope and includes sell/destroy controls. Its addon TOC says Interface 30300/version 0.9, while the addon README says v0.8; verify the matching client protocol before deployment. Source creates its tables at startup; none are installed yet. |
| [mod-bot-quiet-rolls][bot-quiet-rolls] | Conditional candidate | Hides Playerbot “passed” chat spam while retaining the actual roll. | Relevant only if normal rolls are kept. Requires the matching Playerbot fork support. |
| [mod-junk-to-gold-plus][junk-to-gold-plus] | Reference only; delivered as Warband's trash auto-sell | Automatically sells protected-safe gray loot. | Warband built its own on 16 October 2026: grey sold on pickup, quest items and quest-start items kept, gold to whoever looted. Read from source — one `PlayerScript::OnPlayerLootItem` hook, no core change — but do not copy its protections blindly: it also keeps grey armour/weapon "upgrades" and caches both config flags in function-local statics, so a config reload never reaches them. A convergence aid for bag space, not a backlog feature. |
| [mod-autosort][autosort] | Convenience candidate | Sorts inventory. | Leader quality of life only; not a follower-item policy. |
| [mod-e-interact][e-interact] | Convenience candidate | One key for looting, gathering, NPC interaction, quest dialogs, and rolls. | Complements AoE Loot; partly overlaps Auto Gather only for manual gathering interaction. |

## Auction House

| Item | Status for evaluation | What it contributes | Important boundary |
|---|---|---|---|
| Existing Playerbots AH code | Not an active AH feature | The checked-out Playerbots source contains an `AuctionItem` helper in `LootAction.cpp`, but the whole helper is inside a block comment; no active listing/buying config option was found. | Do not count the already-built Playerbots module as normal-AH buy/sell. A separate active AH module or Warband implementation is still needed. |
| [Official mod-ah-bot][ah-bot] | Reference only; not taken up | Seller listings and optional bot buying in the faction Auction Houses. | Requires world SQL tables and a bot account/character. Kept as the reference for what the market needs; the fork below was chosen instead because it needs no database schema at all. |
| [mod-ah-bot-plus][ah-bot-plus] | **Approved dependency, installed 16 October 2026** | The auction-house market: seller stock for all three houses plus a buyer for player listings, configured entirely in one file. | The single recorded exception to the in-house rule (see the implementation policy): writing a market is a project of its own. Verified before install: no SQL at all, its required core commit `3f46e05` is an ancestor of this checkout, and its buyer pays the seller by mail while spending nothing itself. Warband owns the control surface — `.warband ah` and the panel's Auction house page — and never runs a second AH bot alongside it. |
| [Black-Market-Auction-House][bmah] | Local copy under `extras/`; intentionally held inactive | Eluna-style script plus matching 3.3.5 client UI for bidding on configured offers, outbid refunds, and mailed winnings. | Current scope requires buying and selling; this candidate lacks player item listings/selling, so do not activate it until that is supported. The test NPC entry `2069430` is absent; dedicated NPC/client setup and ALE compatibility also remain unverified. Loading creates a character DB table and starts auction timers. |

## Leader-paced growth and catch-up

| Item | Status for evaluation | What it contributes | Overlap / question |
|---|---|---|---|
| AzerothCore `Rate.XP.*` settings | Built-in configuration; template currently uses 1x | Adjusts server-wide XP from kills, quests, exploration, pets, and battlegrounds without adding a module. | Useful if the player wants a different overall XP pace. It does not give followers a larger multiplier based on their level gap from the leader. |
| [mod-xp-dynamic][xp-dynamic] | Reference only; not taken up | Level-bracket/source-based XP rates and a bonus for account characters below a max-level account character. | Does not implement the desired leader-relative level-gap bonus for newly recruited AltBots. It also brings an account-table SQL update and requires a C++ rebuild. Do not treat it as the catch-up solution; a Warband-specific implementation or another candidate is needed. |
| [mod-individual-rates][individual-rates] | Broad rate-control alternative | Account/character XP, reputation, skill, drop, and money rates. | Overlaps XP Dynamic as the general rate authority. It does not itself implement follower catch-up. |
| [mod-accountwide][accountwide] | Optional account-progression candidate | Shares selected achievements, cosmetics, reputation, currencies, and PvP across real characters. | Explicitly skips Playerbots, so it is not follower campaign synchronization or catch-up. Each shared system needs an individual scope decision. |

## Dungeons, raid future, and world adaptation

| Item | Status for evaluation | What it contributes | Overlap / question |
|---|---|---|---|
| [mod-dungeon-clear][dungeon-clear] | Candidate for an optional mode | Tank Playerbot routes, pulls, rests, loots, and handles many dungeon events. | Bot-led dungeon mode; compare with Dungeon Lead. It is not required for leader-led outdoor campaign play. |
| [mod-playerbots-dungeon-lead][dungeon-lead] | Candidate for an optional mode | Alternative tank-led 5-man dungeon routing. | Work in progress with partial live coverage; choose instead of Dungeon Clear if this mode is wanted. |
| [mod-raid-clear][raid-clear] | Later reference | Teaches bots mechanics for ordinary raids. | Does not turn raids into leader + four-follower content. |
| [mod-optimal-bot-raid][optimal-bot-raid] | Later reference | Organizes conventional Playerbot raids. | Does not downscale raids to five members. |

The five-member downscaling of raids and large world events remains a Warband
implementation task. It is not supplied by the two raid modules above.

## Appearance, builds, and solo-world convenience

| Item | Status for evaluation | What it contributes | Overlap / question |
|---|---|---|---|
| [mod-transmog][transmog] | Reference only; not taken up (closed 16 October 2026) | Standard AzerothCore transmogrification. | Read in full: a gossip NPC that records appearances per character and overrides display on **player** items. No bot involvement anywhere, so companions cannot wear a look — a party that only dresses its leader was judged not worth the dependency. |
| [Retail Transmog Plus][retail-transmog-plus] | Reference only; repository not verifiable | Account-wide collection, sets/outfits, and client UI. | The repository named in earlier research no longer resolves, so nothing current is known about it; it would have the same "players only" limit as the official module. |
| [mod-talentbutton][talentbutton] | Build convenience candidate | Early dual spec and remote talent reset. | Verify AltBot workflow before selection. |
| [mod-no-hearthstone-cooldown][no-hearth] | Convenience candidate | Removes the Hearthstone cooldown. | Travel-pacing preference. |
| [mod-all-flightpaths][all-flightpaths] | Convenience candidate | Unlocks flight paths automatically. | Removes travel discovery; preference decision. |
| [mod-warband-camp][warband-camp] | Later thematic option | Account-wide camp services, dummies, and rested XP. | Expands beyond the current combat-follower scope. |
| [mod-boss-archive][boss-archive] | Later loot-safety option | Recoverable/archive-style boss loot. | Changes farming and gear acquisition; decide after the basic loot workflow. |

## Kept as references or deferred, not active candidates

| Item | Why it is not in the active selection set |
|---|---|
| [mod-quest-loot-party][quest-loot-party] | The Nexartgroup fork says the older PR #16509 dependency is obsolete because the hook exists in current AzerothCore. Its options still require a quest on each recipient or duplicate the same loot to every eligible member; it does not provide leader-only turn-in or role-aware gear routing. Personal loot multiplies item income and needs careful review. |
| [mod-autosell-grey][autosell-grey] | Duplicates Junk to Gold Plus while adding an Eluna dependency and direct core patch; it also excludes bots. |
| [mod-rndbot-sync][rndbot-sync] | Intentionally excludes owned/party bots, so it cannot catch up Warband followers. Useful only as a design reference. |
| [mod-xp-dynamic][xp-dynamic] | Its alt bonus is based on max-level characters on the account, not a follower's level gap from the leader. It also requires account SQL and a C++ rebuild; retain only as a general-rate reference unless that different alt-bonus mechanic is desired. |
| [mod-open-world-party-scaling][open-world-party-scaling] | Increases difficulty for parties; Warband needs downscaling for five-member events and raids. |
| [mod-quest-radar][quest-radar] | Requires its matching client addon. Defer to the client-addon phase. |
| [mod-forever-journal][forever-journal] | Includes a client component and is planning/reference UI rather than a companion-system need. |

## Choices that overlap

These are choices to evaluate one at a time; selecting one does not select the
rest of its row.

| Decision | Alternatives |
|---|---|
| Loot method | Free-For-All with Shared Loot, or normal rolls plus the existing MultiBot/Playerbot routing tools. Bot Quiet Rolls matters only for normal rolls. |
| AH market bot | Official `mod-ah-bot`, or `mod-ah-bot-plus` (both reference only; select at most one to study). |
| General XP/rate control | Core rates, XP Dynamic, or Individual Rates; avoid stacking rate authorities. Neither module provides the desired leader-relative AltBot catch-up. |
| Dungeon-led mode | Dungeon Clear, or Dungeon Lead. |
| Appearance system | Standard Transmog, or Retail Transmog Plus. |
| Automatic gray cleanup | Junk to Gold Plus is the preferred candidate; Auto Sell Grey is retained only as a reference. |

[auto-gather]: https://github.com/thanhtong89/mod-auto-gather
[arac]: https://github.com/heyitsbench/mod-arac
[dead-means-dead]: https://github.com/kjack9/mod-dead-means-dead
[dungeon-respawn]: https://github.com/AnchyDev/DungeonRespawn
[aoe-loot]: https://github.com/azerothcore/mod-aoe-loot
[shared-loot]: https://github.com/maluramichael/mod-shared-loot
[shared-gold]: https://github.com/maluramichael/mod-shared-gold
[bot-inventory-master]: https://github.com/TopHatMan/mod-bot-inventory-master
[bot-quiet-rolls]: https://github.com/buildthehomelab/wow-mod-bot-quiet-rolls
[junk-to-gold-plus]: https://github.com/TrisBits/mod-junk-to-gold-plus
[autosort]: https://github.com/silviu20092/mod-autosort
[e-interact]: https://github.com/Rainblower/mod-e-interact
[ah-bot-plus]: https://github.com/NathanHandley/mod-ah-bot-plus
[ah-bot]: https://github.com/azerothcore/mod-ah-bot
[bmah]: https://github.com/Youpeoples/Black-Market-Auction-House
[xp-dynamic]: https://github.com/TopHatMan/mod-xp-dynamic
[individual-rates]: https://github.com/Sphynxmods/mod-individual-rates
[accountwide]: https://github.com/warblups/mod-accountwide
[dungeon-clear]: https://github.com/jrad7/mod-dungeon-clear
[dungeon-lead]: https://github.com/Sugyn/mod-playerbots-dungeon-lead
[raid-clear]: https://github.com/buildthehomelab/wow-mod-raid-clear
[optimal-bot-raid]: https://github.com/barnaclebarry/mod-optimal-bot-raid
[transmog]: https://github.com/azerothcore/mod-transmog
[retail-transmog-plus]: https://github.com/buildthehomelab/wow-mod-retail-transmog-plus
[talentbutton]: https://github.com/brian8544/mod-talentbutton
[no-hearth]: https://github.com/BytesGalore/mod-no-hearthstone-cooldown
[all-flightpaths]: https://github.com/VenomekPL/mod-all-flightpaths
[warband-camp]: https://github.com/Ildourol/mod-warband-camp
[boss-archive]: https://github.com/sbitkov/mod-boss-archive
[quest-loot-party]: https://github.com/nexartgroup/mod-quest-loot-party
[autosell-grey]: https://github.com/Souicia/mod-autosell-grey
[rndbot-sync]: https://github.com/Yuof/mod-rndbot-sync
[open-world-party-scaling]: https://github.com/Stefan2102/mod-open-world-party-scaling
[quest-radar]: https://github.com/warblups/mod-quest-radar
[forever-journal]: https://github.com/buildthehomelab/wow-mod-forever-journal
