# WoW Warband

WoW Warband turns World of Warcraft 3.3.5a into a solo experience. No other players are needed, and
nobody else decides how the party is put together: you play the whole group — a leader plus four
AI-driven companions who fight beside you, level with you, and are shaped as freely as your own
character.

That is the point of the project. Running a five-character party yourself is a different game from
levelling one class: you choose who is in the group and what each of them becomes, you carry five
sets of abilities and five sets of weaknesses at once, and the decisions that usually belong to a
group of players — who tanks, who heals, who carries the gear, who the story belongs to — are yours
to make alone. The companions are permanent characters, not mercenaries hired for the afternoon:
each keeps its own level, equipment and progress, and can be customised for the role it is meant to
fill.

It is built as a customization layer over the
[Playerbot-compatible AzerothCore base](https://github.com/mod-playerbots/azerothcore-wotlk) — for
core installation and server administration, use that project's documentation. This page is the
inventory: which modules run on the server, what Warband itself adds, and how to reach each option.

## What runs on the server

| Module | Whose | What it does |
| --- | --- | --- |
| `mod-warband` | In-house | Every Warband option listed in the next section |
| `mod-playerbots` | Third-party | The companion AI the project is built around |
| `mod-multibot-bridge` | Third-party | Companion command bridge; its client half is `addons/MultiBot` |
| `mod-progression` | Third-party | Content gating by progression phase |
| `mod-ale` | Third-party | Lua scripting support |
| `mod-ah-bot-plus` | Third-party, added | The auction-house market: it stocks all three houses and buys what the party lists |
| `mod-autobalance` | Third-party, added | Instance difficulty scaling: five members can fight a raid built for forty, and a dungeon scales up once the party outlevels it |
| `mod-item-level-scaling` | Third-party, added | Loot scaling: the same items with their stats moved to the party's level, never downward |

Two client addons come from those modules: `addons/MultiBot` (companion commands, inventory and
character windows) and `addons/PlayerbotManager` (companion management UI). Research material for
other modules lives in `doc/` and is not installed.

## What Warband adds

Everything here is Warband's own code, in `modules/mod-warband` on the server and `addons/Warband`
on the client. Each option can be changed while the server runs — no rebuild, no restart.

| Option | What it does | How to change it |
| --- | --- | --- |
| XP multiplier | 1x–10x on every experience gain, followers included. Default 3x | Panel → XP Options, or `.warband xp set <1-10>` |
| Follower catch-up XP | extra experience for a companion that is behind its leader, so a new recruit catches up | Panel → XP Options, or `.warband catchup step/floor/cap/on/off` |
| Follower gathering | companions receive the leader's Herbalism, Mining and Skinning, so they work the same nodes and skin the same corpses. Raise-only | Panel → Follower gathering, or `.warband gather [on\|off\|auto on\|auto off]` |
| Bound gear inside the Warband | with binding off, a soulbound piece trades, mails, auctions and moves to a companion or any other character like any other item; the switch puts the ordinary rule back | Panel → Item binding, or `.warband binding [on\|off]` |
| Magic find | a multiplier per quality on drop chance — shipped x2 green, x4 blue, x6 purple and above. No extra rolls or items | Panel → Magic find, or `.warband magicfind <tier> <multiplier>` |
| Gold find | a multiplier on looted coin. Default x3 | Panel → Gold find, or `.warband goldfind <multiplier>` |
| Trash auto-sell | grey loot is sold the moment it is picked up, for the leader and every companion, so bags stay empty; the vendor price goes to the leader's purse and the page counts only this Warband's sales. `.warband trash sell` empties what is already in the bags | Panel → Trash sell, or `.warband trash [on\|off\|sell]` |
| Instances stop restocking | a creature killed inside a dungeon or raid stays dead for the run, across logging out and server restarts; an instance reset still restores the dungeon | Panel → Instances, or `.warband instance [on\|off]` |
| Auction house control | reads and writes the auction bot's settings — seller and buyer on/off, listings per cycle, buy candidates, stock targets | Panel → Auction house, or `.warband ah seller/buyer/items/candidates/stock/repopulate` |
| World scaling | open-world creatures, quest rewards and loot at each character's own level; the switch flips `mod-zone-scaling`, which is installed and off by default, and only zones the server opted in change | Panel → World scaling, or `.warband worldscale [on\|off]` |
| AoE loot | one loot window holds the nearby corpses' items and gold; the panel exposes the module's whole configuration — switch, group, login message, radius, corpse count, mail fallback — installed and off by default, with `.aoeloot on\|off` per character | Panel → AoE loot, or `.warband aoeloot [on\|off\|message\|group\|mail\|range <5-100>\|corpses <1-50>]` |
| Hearthstone without cooldown | the hearthstone is ready again the moment it is used | `.warband hearthstone [on\|off]` |
| Pets always happy | every hunter pet stays at full happiness, follower pets included | `.warband pets [on\|off]` |
| Party roster | every character on the account listed with level, class and online state, each with an Invite or Dismiss button | **Friends frame → Party tab** (`O`) |
| Companion windows | a member strip above the bag frame and the character sheet opens a companion's inventory or character sheet in MultiBot (shift-click for the other) | click a name on the strip |

The bag frame, the character sheet and the Friends frame are draggable and remember where they were
put.

## Character creation: every race/class combination

All 100 WotLK combinations are available, including Human Shaman and Undead Paladin, and confirmed
in game. The data that applies this is held in the local runtime rather than this repository: world
data for creation, skills and starting spells, the server's `CharStartOutfit.dbc`, the client's
`CharBaseInfo.dbc`, and the client patch `patch-z.mpq`.

## Running it

| Tool | What it does |
| --- | --- |
| `Warband-Server.ps1 start all` / `stop all`, or the start/stop bats | load and unload the database, login server and world server, in order and gracefully |
| `Build-WowWarband.bat` | incremental build with the existing CMake cache; the Playerbots isolate is validated in [the build notes](../doc/Playerbots-Build-Validation.md) |
| `Deploy-WarbandAddon.ps1` | copy `addons/Warband` into the client |
| `Backup-WowWarband.ps1` | back up all four AzerothCore databases |
| `Sync-ProjectReadme.ps1` | keep `.github/README.md` identical to this file |

## Configuration and references

| Where | What |
| --- | --- |
| [`modules/mod-warband/conf/mod_warband.conf.dist`](../modules/mod-warband/conf/mod_warband.conf.dist) | every Warband server option, installed as `bin/RelWithDebInfo/configs/modules/mod_warband.conf` |
| [Module README](../modules/mod-warband/README.md) | each option in detail, and the command protocol |
| [Addon README](../addons/Warband/README.md) | the client panel, page by page |
| [Feature backlog](../doc/Warband-Feature-Backlog.md) | what exists, what is wanted, and what was decided against |
| [Design record](../doc/Warband-Design.md), [implementation policy](../doc/Warband-Implementation-Policy.md) | the project's rationale and rules |
| [Module shortlist](../doc/Warband-Server-Module-Shortlist.md), [module assessment](../doc/Warband-Module-Assessment.md) | the research the module choices came from |
| [Setup and source layout](../WowWarband-Setup.md) | local development workflow |

Runtime files — the built server, the client copy, extracted map data, database files and local
credentials — stay outside version control.
