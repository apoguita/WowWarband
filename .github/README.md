# WoW Warband

WoW Warband is a personal, single-player World of Warcraft 3.3.5a project built
around a party of AI-controlled companions. The aim is to make Azeroth feel more
like a Guild Wars 1 hero-party campaign than a conventional solo private-server
repack: the player leads the story while a small, persistent team fights beside
them.

This repository is a customization layer over the
[Playerbot-compatible AzerothCore base](https://github.com/mod-playerbots/azerothcore-wotlk).
For core installation, server administration, and general AzerothCore
development, use that project's documentation. This README describes what makes
**WoW Warband** different.

## Current focus

The active design direction is a leader and a party of **AltBot followers**:

- Companions fight, follow, and fill chosen party roles.
- The player shapes a companion through equipment, talents/builds, and
  appearance.
- Character creation is intended to support every WotLK race/class combination,
  including Human Shaman and Undead Paladin. The local ARAC data integration is
  installed, but character creation still needs in-game verification.
- Companions are intended to feel like heroes, not independently managed alts.
  Their underlying character inventories and quest state exist only where the
  technology requires them; routine inventory, profession, and quest-log
  management are outside the desired player experience.
- The intended growth curve unlocks the full five-member group (leader plus
  four companions) by level 15. New followers begin at level 1 and are intended
  to catch up through a level-gap XP system; its exact curve and implementation
  still need validation.
- Raids are a later goal, but they must be downscaled or otherwise adapted for
  that same five-member group rather than requiring a conventional raid roster.
- The leader should set the campaign pace. Shared campaign progress and
  leader-led quest completion are promising directions under evaluation, not
  implemented promises.

Read [the Warband design document](../doc/Warband-Design.md) for the decisions,
preferred behavior, alternatives, and unresolved technical questions. It is the
source of truth for the product direction.

For candidate modules, overlapping features, and deferred setup work, see the
[server-module shortlist](../doc/Warband-Server-Module-Shortlist.md) and
[module assessment](../doc/Warband-Module-Assessment.md). The
[full AzerothCore server-module catalogue](../doc/AzerothCore-Server-Module-Catalogue.md)
is available for broader exploration; catalogue presence does not mean a
module is compatible, selected, or active.

## Feature ideas and related modules

These are the experiences WoW Warband is assembling. The module names point to
possible building blocks; they do not mean every feature is already active or
that every feature of a module belongs in Warband.

| Feature idea | Related modules or tools | What the feature is for |
| --- | --- | --- |
| A hero party that follows and fights with the leader | [mod-playerbots][playerbots], [mod-multibot-bridge][bridge], [MultiBot Chatless][multibot], [Playerbot Manager][manager] | Bring followers into the campaign and let the player shape and direct their combat roles. |
| A campaign that opens up as the leader progresses | [mod-progression][progression] | Gate content by progression phase. Shared campaign credit and follower catch-up remain separate Warband ideas to explore. |
| More freedom when creating the party | [mod-arac][arac] | Explore every WotLK race/class combination, including Human Shaman and Undead Paladin. |
| Useful gear goes to the companion who needs it | [mod-bot-inventory-master][bot-inventory-master], [mod-warband-unbound-loot][unbound-loot] | Make equipment management and passing items around the Warband easier, without turning general bag management into the main activity. |
| Less repetitive corpse looting and junk handling | [mod-aoe-loot][aoe-loot], [mod-junk-to-gold-plus][junk-to-gold-plus], [mod-shared-gold][shared-gold] | Reduce repeated looting, simplify low-value item handling, and bring supported companion gold to the leader. These tools do not by themselves decide who should equip a drop. |
| Gathering that fits a self-contained solo party | [mod-auto-gather][auto-gather], primary-profession configuration | Make gathering resources and using the WotLK profession roster practical in a single-player world. |
| Buy and sell without building a complex economy simulation | [mod-ah-bot][ah-bot], [Black-Market-Auction-House][bmah] | Provide convenient normal-AH and Black Market access. The desired experience includes buying and selling in both; the current BMAH source is only a bidding candidate. |
| Fewer interruptions during instance runs | [mod-dead-means-dead][dead-means-dead], [DungeonRespawn][dungeon-respawn] | Explore stopping creatures from respawning inside an instance and returning the player to its entrance after death. These are distinct behaviors. |
| Make Warband-specific server behavior easier to extend | [mod-ale][ale], [Keira3][keira], dynamic module build tools | Support project Lua scripts, database editing, and targeted builds of separately linked modules. |

Third-party modules are pinned sources or candidates unless explicitly noted
otherwise. ARAC has been applied to the local runtime but still needs in-game
verification. The in-house unbound-loot and dynamic-loader changes are source
changes and require their documented build and runtime checks. See the
[module shortlist](../doc/Warband-Server-Module-Shortlist.md) and
[module assessment](../doc/Warband-Module-Assessment.md) for component-level status.

## Project-owned additions

These are the changes owned directly by the WoW Warband repository, rather
than pinned third-party components:

| Project-owned feature or workflow | State | What it adds |
| --- | --- | --- |
| `mod-warband-unbound-loot` + core item changes | In-house source change; not yet runtime-verified | Remove binding as a barrier to moving equipment around the Warband. |
| Dynamic module loader and module build scripts | In-house build/runtime support | Build and install selected module DLLs after the initial dynamic build; core changes still require a server rebuild. |
| ALE smoke script | Development helper | Check that the Lua scripting path loads. |
| Build, start, and backup scripts | Local workflow | Help operate and safeguard the local development runtime. |
| [Design document](../doc/Warband-Design.md) | Active design record | Keep settled direction, preferred behavior, alternatives, and open questions distinct. |

Other entries above are third-party modules, data integrations, addons, or
tools. Pinned source is not the same as built or deployed functionality, and
their full feature sets are not automatically part of Warband scope.

## Loot and equipment

The intended experience lets the player direct useful equipment to the right
party role. No item-binding rule should prevent the leader from passing an item
to a follower or moving it elsewhere in the Warband.

The repository includes a small, **unbuilt and untested** in-house implementation:
[`mod-warband-unbound-loot`](../modules/mod-warband-unbound-loot/README.md),
plus small in-house core item changes. Together they prevent new binding flags,
clear existing ones, and remove binding or enchant state as a normal transfer
barrier. They are unbuilt and untested, so this is source direction—not active
server behavior.

Playerbots quest synchronization remains under evaluation for leader-paced quest
completion and reward delivery. It is no longer required merely to work around
item binding.

## Economy and quality of life

Warband should support buying and selling through both the normal Auction House
and the Black Market Auction House. The goal is convenient solo access, not an
elaborate economy simulation. The official `mod-ah-bot` source is a candidate
for normal-AH buying and selling; it has not been built or SQL-applied. The
[BMAH source][bmah] is intentionally held inactive because it currently supports
bidding on configured offers rather than player listings and selling. Its NPC,
client, and runtime compatibility still need verification. Neither candidate is
currently claimed as active Warband functionality.

Loot collection, sorting, routing, and companion-equipment decisions are also
priority quality-of-life areas. Tools that reduce routine friction are welcome
when they reinforce the hero-party loop, but systems that turn companions into
fully independent inventory, profession, or quest-management characters are
outside the intended scope.

## Project state

The local server and client baseline has already been tested: a player can log
in, create a character, play, and use companions that follow and fight. This is
not an installation guide and does not ask contributors to restart setup work.

For this repository's source layout and local development workflow, see
[WowWarband-Setup.md](../WowWarband-Setup.md). Runtime files, client copies,
database data, generated maps, and local credentials remain outside version
control.

## What WoW Warband is not

- Not a generic repack or replacement for the upstream AzerothCore and
  Playerbots documentation.
- Not currently a final specification for shared campaign progress, quest
  synchronization, or the exact companion catch-up curve.
- Not a demand to use every feature provided by MultiBot, Playerbot Manager, or
  Playerbots.
- Not an in-depth Auction House simulation project.

Design choices are intentionally settled one at a time. Please distinguish
implemented behavior from preferred behavior and open questions when adding to
this project.

[playerbots]: https://github.com/mod-playerbots/mod-playerbots
[bridge]: https://github.com/Wishmaster117/mod-multibot-bridge
[multibot]: https://github.com/Wishmaster117/MultiBot-Chatless
[manager]: https://github.com/Lichborne-AC/PlayerbotManager
[progression]: https://github.com/kadeshar/mod-progression
[ale]: https://github.com/azerothcore/mod-ale
[auto-gather]: https://github.com/thanhtong89/mod-auto-gather
[aoe-loot]: https://github.com/azerothcore/mod-aoe-loot
[bot-inventory-master]: https://github.com/TopHatMan/mod-bot-inventory-master
[shared-gold]: https://github.com/maluramichael/mod-shared-gold
[junk-to-gold-plus]: https://github.com/TrisBits/mod-junk-to-gold-plus
[arac]: https://github.com/heyitsbench/mod-arac
[dead-means-dead]: https://github.com/kjack9/mod-dead-means-dead
[dungeon-respawn]: https://github.com/AnchyDev/DungeonRespawn
[ah-bot]: https://github.com/azerothcore/mod-ah-bot
[bmah]: https://github.com/Youpeoples/Black-Market-Auction-House
[unbound-loot]: ../modules/mod-warband-unbound-loot/README.md
[keira]: https://github.com/azerothcore/Keira3
