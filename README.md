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
- Companions are intended to feel like heroes, not independently managed alts.
  Their underlying character inventories and quest state exist only where the
  technology requires them; routine inventory, profession, and quest-log
  management are outside the desired player experience.
- The intended growth curve unlocks a full party of five companions by level
  15. The precise unlock cadence and catch-up rules remain open.
- The leader should set the campaign pace. Shared campaign progress and
  leader-led quest completion are promising directions under evaluation, not
  implemented promises.

Read [the Warband design document](doc/Warband-Design.md) for the decisions,
preferred behavior, alternatives, and unresolved technical questions. It is the
source of truth for the product direction.

## What is included

The project includes the following server and client components. Third-party
components are pinned as Git submodules; Warband-specific work lives in this
repository. Their presence does not mean every available feature is part of the
Warband experience.

| Component | Type | Role in WoW Warband |
| --- | --- | --- |
| [mod-playerbots][playerbots] | Server module | Supplies the AI-controlled characters used as AltBot companions. |
| [mod-multibot-bridge][bridge] | Server module | Structured server link between companion UI and Playerbots. |
| [MultiBot Chatless][multibot] | Client addon | Bridge-backed UI for companion, group, equipment, and loot controls. |
| [Playerbot Manager][manager] | Client addon | Roster, gear, strategy, and build inspection; raid tools are optional. |
| [mod-progression][progression] | Server module | Phase-gated content; the live phase is local runtime configuration. |
| [mod-ale][ale] | Server module | Enables project-owned AzerothCore Lua scripts. |
| [Unbound loot][unbound-loot] | Prototype module | Clears ordinary BoP/BoE item binding. |
| [Keira3][keira] | Development tool | Database editor source, not a player-facing gameplay requirement. |

## Project-owned additions

These are the changes owned directly by the WoW Warband repository, rather
than pinned third-party components:

| Addition | Status | Purpose |
| --- | --- | --- |
| `mod-warband-unbound-loot` | Unbuilt technical prototype | Tests a narrow ordinary-equipment binding-free direction. |
| ALE smoke script | Development smoke test | Confirms the Lua scripting path loads; it adds no gameplay feature. |
| Build, start, and backup scripts | Local workflow | Safeguard the local development runtime. |
| [Warband design document](doc/Warband-Design.md) | Active design record | Separates decisions, alternatives, and open questions. |

There are no other tracked, project-owned gameplay modules at this point. The
remaining listed components are third-party modules, addons, or tools with their
full feature sets intentionally not treated as automatic Warband scope.

## Loot and equipment

The intended experience lets the player direct useful equipment to the right
party role. How to handle Bind on Pickup rewards, companion quest eligibility,
and late-joining companion catch-up is still being designed.

The repository includes a small, **unbuilt and untested** technical prototype:
[`mod-warband-unbound-loot`](modules/mod-warband-unbound-loot/README.md). It
removes ordinary item-instance BoP/BoE binding friction after acquisition or
equipping, but deliberately leaves quest-template items, enchant-caused binding,
and Bind-on-use behavior outside its scope. It is not the project's central
feature and its presence does not mean that binding-free loot has been selected
as the final Warband rule.

The normal AzerothCore group-loot trade window and the Playerbots quest-sync
behavior are also being evaluated before broader loot or progression rules are
chosen. See the design document before treating either as settled behavior.

## Economy and quality of life

Warband should support buying and selling through both the normal Auction House
and the Black Market Auction House. The goal is convenient solo access, not an
elaborate economy simulation. The specific server modules and client addons for
that experience are still being researched; none are claimed here as installed
Warband functionality.

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
[WowWarband-Setup.md](WowWarband-Setup.md). Runtime files, client copies,
database data, generated maps, and local credentials remain outside version
control.

## What WoW Warband is not

- Not a generic repack or replacement for the upstream AzerothCore and
  Playerbots documentation.
- Not currently a final specification for shared campaign progress, quest
  synchronization, binding rules, or companion catch-up.
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
[unbound-loot]: modules/mod-warband-unbound-loot/README.md
[keira]: https://github.com/azerothcore/Keira3
