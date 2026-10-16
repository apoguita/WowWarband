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
**WoW Warband** different, and what is actually installed in this checkout.

## What is installed

"Installed" means a module is present in `modules/` and compiled into the current
build, and an addon is deployed to the client under
`var/client/.../Interface/AddOns`. Nothing else is running.

| Component | Kind | What it is |
| --- | --- | --- |
| `mod-warband` | In-house server module | Warband's own server behaviour, described below. |
| `addons/Warband` | In-house client addon | The control panel: `/warband`, `/ww` or the minimap icon. |
| `mod-playerbots` | Third-party module | The companion AI the project is built around. |
| `mod-multibot-bridge` | Third-party module | Companion chat bridge, with `addons/MultiBot` on the client. |
| `addons/PlayerbotManager` | Third-party addon | Companion management UI. |
| `mod-progression` | Third-party module | Content gating by progression phase. |
| `mod-ale` | Third-party module | Lua scripting support. |

## The in-house Warband module

`modules/mod-warband` is project-owned code and the home for new server-side
Warband features. It needs no core patch: the implementation, including its
Playerbots integration, lives entirely in the module.

| Feature | State |
| --- | --- |
| XP multiplier | Live and verified in game |
| Follower catch-up XP | Live and verified in game |
| Binding-free items | Compiled in; behaviour not yet verified in game |
| Follower gathering | Work in progress in source; not active |

- **XP multiplier** scales every experience gain - kills, quests, exploration and
  battlegrounds - for every character, followers included. It is a whole number
  from 1x to 10x, defaults to 3x, and can be changed while the server runs.
- **Follower catch-up XP** adds extra experience for a companion that is behind
  its leader, so a new recruit becomes useful without replaying the leader's
  history. Only bots piloted for a real player are affected; the random bots that
  populate the world are left alone.
- **Binding-free items** clears the soulbound flag from stored items at login and
  after the normal acquisition paths, so binding stops being a barrier to moving
  equipment around the Warband. Quest-bond items are left as they are.
- **Follower gathering** is being built now and is not registered in the module
  entry point yet, so it is not active on the server.

The client panel in `addons/Warband` is the player-facing side of the module: its
XP Options page reads and sets the live values through the module's `.warband`
chat commands, and its Features list reports what the server answers.

Configuration is `modules/mod-warband/conf/mod_warband.conf.dist`, installed as
`bin/RelWithDebInfo/configs/modules/mod_warband.conf`. The options, the command
protocol, and the state of each feature are documented in the
[module README](../modules/mod-warband/README.md).

## Current focus

The active design direction is a leader and a party of **AltBot followers**:

- Companions fight, follow, and fill chosen party roles.
- The player shapes a companion through equipment, talents/builds, and
  appearance.
- Companions are intended to feel like heroes, not independently managed alts.
  Their underlying character inventories and quest state exist only where the
  technology requires them; routine inventory, profession, and quest-log
  management are outside the desired player experience.
- The intended growth curve unlocks the full five-member group (leader plus four
  companions) by level 15. New followers begin at level 1 and catch up through
  the level-gap XP system described above; the exact curve is still a preference
  rather than a settled decision.
- Raids are a later goal, but they must be downscaled or otherwise adapted for
  that same five-member group rather than requiring a conventional raid roster.
- The leader should set the campaign pace. Shared campaign progress and
  leader-led quest completion are promising directions under evaluation, not
  implemented promises.

Read [the Warband design document](../doc/Warband-Design.md) for the decisions,
preferred behavior, alternatives, and unresolved technical questions. It is the
source of truth for the product direction.

## Character creation: every race/class combination

All 100 WotLK combinations are live in the local runtime, including Human Shaman
and Undead Paladin, and confirmed in game.

**The data that applies this is not in this repository**, so a database rebuild
would lose it. It spans world data for character creation, skills and starting
spells, the server's `CharStartOutfit.dbc` for starting gear, the client's
`CharBaseInfo.dbc` for the combinations the creation screen offers, and the
client patch. Bringing it into version control is tracked in
[the feature backlog](../doc/Warband-Feature-Backlog.md).

## Project-owned workflow

| Addition | What it does |
| --- | --- |
| `Warband-Server.ps1` with the start/stop bats | Load and unload the local stack one component at a time. |
| `Build-WowWarband.bat`, `modules/CMakeLists.txt` | Incremental builds, with Playerbots compiled separately. |
| `Backup-WowWarband.ps1`, `Deploy-WarbandAddon.ps1` | Database backup and client addon deployment. |
| `doc/` | Design record, implementation policy, module research, backlog. |

`Warband-Server.ps1 start all` brings the database, login server and world server
up in order and waits until each one is ready. `stop all` shuts them down
gracefully - saving characters - and reaps anything an earlier launch left behind.
The Playerbots compilation isolation is validated in
[the build notes](../doc/Playerbots-Build-Validation.md).

## Project state

The local server and client baseline works: a player can log in, create a
character, play, and use companions that follow and fight. This is not an
installation guide and does not ask contributors to restart setup work.

For this repository's source layout and local development workflow, see
[WowWarband-Setup.md](../WowWarband-Setup.md). Runtime files, client copies,
database data, generated maps, and local credentials remain outside version
control.

## What WoW Warband is not

- Not a generic repack or a replacement for the upstream AzerothCore and
  Playerbots documentation.
- Not currently a final specification for shared campaign progress, quest
  synchronization, or the exact companion catch-up curve.
- Not a demand to use every feature provided by MultiBot, Playerbot Manager, or
  Playerbots.
- Not an in-depth Auction House simulation project.

Design choices are intentionally settled one at a time. Please distinguish
implemented behavior from preferred behavior and open questions when adding to
this project.
