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
| `mod-ah-bot-plus` | Third-party module | The auction-house market: it stocks all three houses and buys what the party lists. An approved dependency, because writing a market is a project of its own |
| `mod-autobalance` | Third-party module | Instance difficulty scaling: five members can fight a raid built for forty, and a dungeon scales up once the party outlevels it. An approved dependency |
| `mod-item-level-scaling` | Third-party module | Loot scaling: the same items with their stats moved to the party's level, never downward. An approved dependency |

**Warband implements every feature in-house unless a recorded decision says otherwise.** Third-party
modules and addons are reference material: never a dependency, never an install step, never part
of the build — with three recorded exceptions, the auction-house market (`mod-ah-bot-plus`) and the
two scaling modules (`mod-autobalance`, `mod-item-level-scaling`), each named and justified in the
[implementation policy](../doc/Warband-Implementation-Policy.md). Nothing else is staged in this
checkout — `modules/` holds the runtime baseline, `mod-warband` and those dependencies, no
researched module is a submodule, and the read-only research clones under `.agents/reference/` are
never built. A link in the research documents is a citation of where a behaviour was studied,
nothing more.

Modules that were only *researched* are not installed and are not part of the
build. That research lives in
[the server-module shortlist](../doc/Warband-Server-Module-Shortlist.md),
[the module assessment](../doc/Warband-Module-Assessment.md) and
[the AzerothCore module catalogue](../doc/AzerothCore-Server-Module-Catalogue.md);
appearing there means a module was evaluated, nothing more.

## The in-house Warband module

`modules/mod-warband` is project-owned code and the home for new server-side
Warband features. It carries one small core change - the item binding policy in
`Item.cpp` - and nothing else outside the module; the reason is documented in the
[module README](../modules/mod-warband/README.md).

| Feature | State |
| --- | --- |
| XP multiplier | Live and verified in game |
| Follower catch-up XP | Live and verified in game |
| Follower gathering | Live; the on-demand apply is verified in game, the automatic sync is not yet |
| Bound gear inside the Warband | Built; not yet verified in game |
| Magic find | Built; not yet verified in game |
| Gold find | Built; not yet verified in game |
| Trash auto-sell | Built; not yet verified in game |
| Instances stop restocking | Built; not yet verified in game |

- **XP multiplier** scales every experience gain - kills, quests, exploration and
  battlegrounds - for every character, followers included. It is a whole number
  from 1x to 10x, defaults to 3x, and can be changed while the server runs.
- **Follower catch-up XP** adds extra experience for a companion that is behind
  its leader, so a new recruit becomes useful without replaying the leader's
  history. Only bots piloted for a real player are affected; the random bots that
  populate the world are left alone.
- **Bound gear inside the Warband** treats a bound item as bound to the party rather
  than to one character. With binding off, which is the default here, a soulbound
  piece can be traded, mailed, auctioned and handed to a companion like any other
  item, and the item keeps its soulbound flag throughout. A switch on the panel's
  Item binding page turns the ordinary rule back on, and the server enforces whatever
  the switch says - this is the one Warband feature that changes the core, because the
  trade, mail and auction paths ask the core directly and none of them has a hook.
- **Magic find** raise the odds of the better qualities without touching
  the tables or the item count: a multiplier per quality, shipped as x2 greens, x4 blues,
  x6 purple and above. A 3% legendary row becomes 18%, a 20% blue becomes 80%, and
  anything past 100% simply becomes a guaranteed drop. No extra rolls, no duplicates, no
  extra items, and poor and normal are never touched. It applies to the Warband's own
  loot only, and the panel's Magic find page sets the five multipliers live.
- **Gold find** is the same idea for money: a multiplier on the coin that loot generates,
  shipped at x3, so a 50 silver pile becomes 1 gold 50. It covers creatures, chests,
  mines and containers, and it leaves vendoring, quest rewards, mail and the auction
  house alone.
- **Trash auto-sell** is about bag space, not money: a grey item is sold the moment it is
  picked up, so it never occupies a slot, and the copper goes to whoever looted it. It
  covers the leader and every companion, because a companion's bags are the ones nobody
  can empty by hand. Quest items, quest-starting items and anything an accepted quest
  still needs are never sold. A bag that is already full cannot be emptied by looting, so
  `.warband trash sell` - or the panel's button - sweeps the whole party's bags.
- **Instances stop restocking**: a creature killed inside a dungeon or raid stays dead for the
  run. The death is saved to the character database, so leaving for a while, logging out or a
  server restart does not bring the trash back, while an instance reset - manual or the daily one -
  still restores the whole dungeon. Open-world respawns are untouched, and the panel's Instances
  page switches the rule on and off live.
- **Follower gathering** gives every companion in the party the leader's Herbalism,
  Mining and Skinning values, so they can work the same nodes and skin the same
  corpses without owning a crafting profession. It is a floor, never a ceiling:
  companions are only ever raised, so a member that was trained further, or that
  was the character the player logged in as in an earlier session, keeps its own
  progress. The mirror applies on leader login, when a companion joins the party,
  and whenever a gathering skill changes while playing. Whether the companions
  could gather at all was the open question in the backlog; this is the answer.

The client panel in `addons/Warband` is the player-facing side of the module: its
XP Options page reads and sets the live values through the module's `.warband`
chat commands, its Follower gathering page reports the mirror and can apply it on
demand, and its Features list reports what the server answers. The panel also
carries a member strip on the bag frame and on the character sheet, which opens a
companion's inventory or character sheet in MultiBot, and the bag and character
frames themselves are draggable and remember where they were put.

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
| `Sync-ProjectReadme.ps1` | Keeps `.github/README.md`, the copy GitHub renders, in step with this file. |
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
