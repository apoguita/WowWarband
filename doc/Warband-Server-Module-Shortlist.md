# Warband server-module shortlist

This is the current source-integration and evaluation list. Entries marked
**Source staged** are pinned in this repository but are not built, enabled, or
tested here. Their configs and SQL have not been applied to the runtime. Where
alternatives remain undecided, they stay documented as options rather than
being installed together.

`mod-warband-unbound-loot` is project-owned code, not a catalogue candidate. It
now has matching in-house core changes for the binding-free item policy. Those
changes are unbuilt and require a future `worldserver` rebuild before testing.

## Requested foundation

| Item | Status for evaluation | What it contributes | Important boundary |
|---|---|---|---|
| [mod-auto-gather][auto-gather] | Source staged; not built | Automatic nearby herbs, ore, and skinning. | Its player update hook does not exclude Playerbots. It only acts when a character has a relevant gathering skill, so follower behavior needs a policy/test; do not grant followers professions just to use it. |
| [mod-arac][arac] | Local data integration applied; gameplay verification pending | All WotLK race/class combinations, including Human Shaman and Undead Paladin. | World SQL applied; server DBC files replaced with a reversible backup under ignored `var/backups/`; client patch added as `patch-z.mpq`, preserving the existing `patch-a.mpq`. The database has 100 race/class combinations. No C++ build was needed; verify client patch loading and character creation in-game. |
| [mod-dead-means-dead][dead-means-dead] | Source staged; not built | Prevents creature respawns in dungeons and raids by default; can customize creature respawn times. | Separate from character death recovery. Its README warns that an instance unload can restore normal respawn timing; do not change `Instance.UnloadDelay` without separate review. |
| [DungeonRespawn][dungeon-respawn] | Source staged; archived, not built | Returns a character to the dungeon entrance after death. | Separate from creature respawn suppression. Repository archived in 2025; compile/API compatibility and character SQL need review before activation. |

## Loot, equipment, and follower housekeeping

| Item | Status for evaluation | What it contributes | Overlap / question |
|---|---|---|---|
| [mod-aoe-loot][aoe-loot] | Source staged; not built or SQL-applied | One loot interaction collects nearby corpses. | Collection only; it does not decide the equipment recipient. Upstream stores messages in `module_string`/`module_string_locale`; inspect the shipped module SQL before applying it. |
| [mod-quest-loot-party][quest-loot-party] | Candidate fork; not staged | Optional sharing of quest-objective items to party members who have and still need the quest, forced quest-item drops, or same-loot personal drops. | The fork says its hooks are already in AzerothCore, but it does not handle leader-only quest turn-ins or role-aware gear assignment. Personal drops duplicate eligible items to every group member and can multiply bag pressure and item supply. Experimental; review before considering. |
| [mod-shared-loot][shared-loot] | Candidate | Removes need/greed/round-robin prompts by forcing Free-For-All. | A loot-method choice, not automatic role-aware assignment. Compare with keeping normal rolls and using MultiBot/manual routing. |
| [mod-shared-gold][shared-gold] | Source staged; not built | Routes defined owned-Playerbot gold sources to the leader. | Separate from item routing and does not route AH proceeds. It only recognizes marked vendor/quest money paths; Junk to Gold Plus credits directly through `ModifyMoney`, so that auto-sale proceeds path will not automatically route to the leader. |
| [mod-bot-inventory-master][bot-inventory-master] | Server source and bundled client UI staged; not built or deployed | Online same-account equipment commands plus a bundled 3.3.5 UI with equipment, individual bags, and party-bag cleanup views. | The UI is broader than Warband's equipment-first player-facing scope and includes sell/destroy controls. Its addon TOC says Interface 30300/version 0.9, while the addon README says v0.8; verify the matching client protocol before deployment. Source creates its tables at startup; none are installed yet. |
| [mod-bot-quiet-rolls][bot-quiet-rolls] | Conditional candidate | Hides Playerbot “passed” chat spam while retaining the actual roll. | Relevant only if normal rolls are kept. Requires the matching Playerbot fork support. |
| [mod-junk-to-gold-plus][junk-to-gold-plus] | Source staged; not built | Automatically sells protected-safe gray loot. | The preferred single auto-sell option. Verify owned-bot behavior and protections in this fork before enabling. Do not combine with another auto-sell system. |
| [mod-autosort][autosort] | Convenience candidate | Sorts inventory. | Leader quality of life only; not a follower-item policy. |
| [mod-e-interact][e-interact] | Convenience candidate | One key for looting, gathering, NPC interaction, quest dialogs, and rolls. | Complements AoE Loot; partly overlaps Auto Gather only for manual gathering interaction. |

## Auction House

| Item | Status for evaluation | What it contributes | Important boundary |
|---|---|---|---|
| Existing Playerbots AH code | Not an active AH feature | The checked-out Playerbots source contains an `AuctionItem` helper in `LootAction.cpp`, but the whole helper is inside a block comment; no active listing/buying config option was found. | Do not count the already-built Playerbots module as normal-AH buy/sell. A separate active AH module or Warband implementation is still needed. |
| [Official mod-ah-bot][ah-bot] | Source staged; not built or SQL-applied | Seller listings and optional bot buying in the faction Auction Houses. | Requires world SQL and a configured bot account/character. The documented core minimum is satisfied by the current checkout, but source has not been built or tested. Decide on one AH bot, not multiple overlapping bots. |
| [mod-ah-bot-plus][ah-bot-plus] | Not staged; source candidate | Normal AH seller listings and an optional buyer for player listings. | Supports the requested normal-AH buying and selling without a detailed economy simulation. Its documented minimum core commit is already an ancestor of this checkout, but no build/source integration has verified it. It does not implement Black Market Auction House behavior. |
| [Black-Market-Auction-House][bmah] | Source pinned; intentionally held inactive | Eluna-style script plus matching 3.3.5 client UI for bidding on configured offers, outbid refunds, and mailed winnings. | Current scope requires buying and selling; this candidate lacks player item listings/selling, so do not activate it until that is supported. The test NPC entry `2069430` is absent; dedicated NPC/client setup and ALE compatibility also remain unverified. Loading creates a character DB table and starts auction timers. |

## Leader-paced growth and catch-up

| Item | Status for evaluation | What it contributes | Overlap / question |
|---|---|---|---|
| AzerothCore `Rate.XP.*` settings | Built-in configuration; template currently uses 1x | Adjusts server-wide XP from kills, quests, exploration, pets, and battlegrounds without adding a module. | Useful if the player wants a different overall XP pace. It does not give followers a larger multiplier based on their level gap from the leader. |
| [mod-xp-dynamic][xp-dynamic] | Reference only; not staged | Level-bracket/source-based XP rates and a bonus for account characters below a max-level account character. | Does not implement the desired leader-relative level-gap bonus for newly recruited AltBots. It also brings an account-table SQL update and requires a C++ rebuild. Do not treat it as the catch-up solution; a Warband-specific implementation or another candidate is needed. |
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
| [mod-transmog][transmog] | Appearance candidate | Standard AzerothCore transmogrification. | Choose instead of Retail Transmog Plus. |
| [Retail Transmog Plus][retail-transmog-plus] | Broader appearance alternative | Account-wide collection, sets/outfits, and client UI. | More than basic appearance control; requires client work. Choose instead of standard Transmog. |
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
| AH market bot | Official `mod-ah-bot` (source pinned), or `mod-ah-bot-plus` (source not staged); select at most one. |
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
