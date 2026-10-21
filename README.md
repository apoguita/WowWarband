# WoW Warband

WoW Warband turns World of Warcraft 3.3.5a into a solo experience. No other players are needed, and
nobody else decides how the party is put together: you play the whole group â€” a leader plus four
AI-driven companions who fight beside you, level with you, and are shaped as freely as your own
character.

That is the point of the project. Running a five-character party yourself is a different game from
levelling one class: you choose who is in the group and what each of them becomes, you carry five
sets of abilities and five sets of weaknesses at once, and the decisions that usually belong to a
group of players â€” who tanks, who heals, who carries the gear, who the story belongs to â€” are yours
to make alone. The companions are permanent characters, not mercenaries hired for the afternoon:
each keeps its own level, equipment and progress, and can be customised for the role it is meant to
fill.

It is built as a customization layer over the
[Playerbot-compatible AzerothCore base](https://github.com/mod-playerbots/azerothcore-wotlk) â€” for
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
| REMOVED: `mod-ah-bot-plus` | Third-party, added | The auction-house market: it stocks all three houses and buys what the party lists. Withdrawn â€” the auction house it served is now the Warband merchant network below |
| `mod-autobalance` | Third-party, added | Instance difficulty scaling: five members can fight a raid built for forty, and a dungeon scales up once the party outlevels it |
| `mod-item-level-scaling` | Third-party, added | Loot scaling: the same items with their stats moved to the party's level, never downward; also grants quest reward equipment at the quest's presented level (`ItemScaling.QuestRewards`) |
| `mod-zone-scaling` | Third-party, added | Open-world per-player level scaling, active: creatures present at each character's own level, upward only (`ZoneScaling.Direction = "up"`), quest XP is owned by the Warband quest-scaling rule below |

Two client addons come from those modules: `addons/MultiBot` (companion commands, inventory and
character windows) and `addons/PlayerbotManager` (companion management UI). Research material for
other modules lives in `doc/` and is not installed.

Two more client addons are Warband's own: `addons/Warband` (the settings panel, its pages, and the
Dungeon Finder window it turns into the destination travel menu).

## What Warband adds

Everything here is Warband's own code, in `modules/mod-warband` on the server and `addons/Warband`
on the client. Each option can be changed while the server runs â€” no rebuild, no restart â€” and the
value is saved, so it survives the next restart.

| Option | What it does | How to change it |
| --- | --- | --- |
| Auction house replaced by merchants | every auctioneer, in every city, is now a Warband merchant: clicking one opens a category menu instead of the auction house, stocking **everything a profession can make** â€” 7,350 items, unlimited quantity â€” and buying anything you sell at the same price. The menu is Armor (type â†’ slot â†’ level range 1-10 â€¦ 71-80), Weapons (family, one- and two-handed), Containers, Materials and reagents, Consumables, Glyphs (by class), Gems, Recipes (by profession), Ammunition and Keys | Panel â†’ Supplier prices, or `.warband price <tier> <multiplier>` / `floor` / `apply` / `reset` |
| Soul shards from any kill | Drain Soul grants its Soul Shard on any kill, not only on a target that yields experience or honor, and its per-tick shard chance follows the same rule; Shadowburn's shard refund too | server-side rule, no switch â€” `.warband` has nothing to set |
| Soulstones never expire | the resurrection buff a Soulstone carries lasts until it is used, instead of the shipped 15 minutes, so a shard waits for the death it was made for | server-side rule, no switch |
| XP multiplier | 1xâ€“10x on every experience gain, followers included. Default 2x | Panel â†’ XP Options, or `.warband xp set <1-10>` |
| Follower catch-up XP | extra experience for a companion that is behind its leader, so a new recruit catches up | Panel â†’ XP Options, or `.warband catchup step/floor/cap/on/off` |
| Follower gathering | companions receive the leader's Herbalism, Mining and Skinning, so they work the same nodes and skin the same corpses. Raise-only | Panel â†’ Follower gathering, or `.warband gather [on\|off\|auto on\|auto off]` |
| Bound gear inside the Warband | with binding off, a soulbound piece trades, mails, auctions and moves to a companion or any other character like any other item; the switch puts the ordinary rule back | Panel â†’ Item binding, or `.warband binding [on\|off]` |
| Magic find | a multiplier per quality on drop chance â€” shipped x2 green, x4 blue, x6 purple and above. No extra rolls or items | Panel â†’ Magic find, or `.warband magicfind <tier> <multiplier>` |
| Gold find | a multiplier on looted coin and on what merchants pay for items sold to them, trash auto-sell and quest gold included. Default x3 | Panel â†’ Gold find, or `.warband goldfind <multiplier>` |
| Trash auto-sell | grey loot is sold the moment it is picked up, for the leader and every companion, so bags stay empty; the vendor price times the gold multiplier goes to the leader's purse and the page counts only this Warband's sales. `.warband trash sell` empties what is already in the bags | Panel â†’ Trash sell, or `.warband trash [on\|off\|sell]` |
| Instances stop restocking | a creature killed inside a dungeon or raid stays dead for the run, across logging out and server restarts; an instance reset still restores the dungeon | Panel â†’ Instances, or `.warband instance [on\|off]` |
| Dungeon Finder travels the party | on a single-player server the queue matched nobody, so the finder's pick is answered with travel instead: choose a dungeon (or a Random Dungeon) and press Find Group, and the whole party lands at that dungeon's entrance, companions included. The retail rules still decide who may enter (level, attunement, raid group, the hourly instance limit), the entry's own difficulty is applied, and the instance exit portal brings the party back to where it entered. The finder window itself only draws the dungeons its own level data allows, so the Warband addon turns that whole window into the travel menu instead: opening the Dungeon Finder shows a plain panel listing the server's whole table — every dungeon, heroic and raid it has an entrance for, nothing filtered or greyed, coloured for your level and with a Travel button per row — and the queue view is never drawn | open the Dungeon Finder, or `.warband travel [<dungeon id>]` |
| World scaling | open-world creatures present at each character's own level, **upward only**: a creature below you comes up to meet you, one above you is never brought down. Enabled for every zone; each character carries its own view, so a five-member party can fight the same boar at its own levels. Dungeons and raids are not touched by it (they belong to the instance scalers) | Panel â†’ World scaling, or `.warband worldscale [on\|off]` |
| Quest level scaling | quests present at the highest **5-level step** the character has reached, so they never slide into the gray band as the character levels: a level-15 quest reads â€” and pays â€” as a level-20 quest once you are 20-24, then as level 25 from 25. The displayed level (quest log, con colour, XP preview), the awarded experience and the quest's equipment rewards all follow it. Never lowered; a quest already above the character keeps its own level | `Warband.Quests.ScaleStep` (`0` turns it off) and `ItemScaling.QuestRewards` |
| Engineering bots priced by hand | the repair-and-vendor summoning bots are priced for actual use instead of the copper floor or a material-driven inflation: **Jeeves 1,000g**, Field Repair Bot 74A and 110G about **25s** each | the supplier's `warband_supplier_price` rows, applied by the catalogue update |
| Jeeves on a 3-minute cooldown | the portable vendor/bank/repair bot can be re-summoned every 3 minutes instead of once an hour | server-side item data, no switch |
| AoE loot | one loot window holds the nearby corpses' items and gold; the panel exposes the module's whole configuration â€” switch, group, login message, radius, corpse count, mail fallback â€” installed and off by default, with `.aoeloot on\|off` per character | Panel â†’ AoE loot, or `.warband aoeloot [on\|off\|message\|group\|mail\|range <5-100>\|corpses <1-50>]` |
| World bots | the random bots playerbots logs in and out by itself: switch the population off for an empty world, or pin how many stay online; the Warband's own companions are never touched, and the default is the playerbots configuration | Panel â†’ World bots, or `.warband randombots [on\|off\|set <1-500>]` |
| Companion pays in a trade | a small panel attaches to the trade window, showing the companion's purse and gold/silver/copper steppers, so a follower can pay without the bot's whisper sequence; the trade itself is an ordinary trade | the panel, or `.warband trade [gold <amount>]` |
| Hearthstone without cooldown | the hearthstone is ready again the moment it is used | `.warband hearthstone [on\|off]` |
| Pets always happy | every hunter pet stays at full happiness, follower pets included | `.warband pets [on\|off]` |
| Party roster | every character on the account listed with level, class and online state, each with an Invite or Dismiss button | **Friends frame â†’ Party tab** (`O`) |
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
| `Build-WowWarband.bat` | incremental build with the existing CMake cache; the Playerbots isolate is validated in [the build notes](doc/Playerbots-Build-Validation.md) |
| `Deploy-WarbandAddon.ps1` | copy `addons/Warband` into the client |
| `Warband-ClearClientCaches.ps1` | rebuild the client item cache so tooltips re-query the server instead of showing a cached price; `Start-WowWarband.bat` runs it on every launch |
| `Warband-Configs.ps1 -Action apply` | carry this project's configuration decisions onto the installed server configs â€” see below |
| `Backup-WowWarband.ps1` | back up all four AzerothCore databases |
| `Sync-ProjectReadme.ps1` | keep `.github/README.md` identical to this file |

### Config decisions travel with the repository

Anything the project deliberately changes in a server config is recorded in `data/configs/` and
applied by `Warband-Configs.ps1`, so a fresh clone ends up with the same behaviour:

    .\Warband-Configs.ps1 -Action check     report drift between data/configs and the installed configs
    .\Warband-Configs.ps1 -Action apply     write the recorded values into the installed configs
    .\Warband-Configs.ps1 -Action export    capture what this install currently changes, to be committed

`apply` touches **only** the keys named in `data/configs/` and leaves the rest of each file alone.
Whole files are never copied: a `worldserver.conf` carries database credentials and a machine path
(`DataDir`), and copying one over someone else's install would break their server. Those keys are
excluded from `export` for that reason.

What it currently carries: the local bind address, `EnablePlayerSettings`, eleven primary trade
skills, **guild charters that need no signatures** (`MinPetitionSigns = 0` â€” a Warband is one player
plus bots, and a bot cannot sign a charter), Playerbots' random-bot population and autologin (off)
and **NEED rolls instead of greed**, AoE-loot mail fallback, AutoBalance's money and higher-level
rules, and item-level scaling without scale-down.

**Database content ships the same way â€” through AzerothCore's own updater.** Anything this project
adds to the world database is committed as a pending update under
`data/sql/updates/pending_db_world/`, which the worldserver applies once on its first start
(`Updates.EnableDatabases` in `worldserver.conf`). Nothing has to be imported by hand: clone, build,
start. The supplier merchants are distributed this way â€” 29 converted auctioneers, 83 menus, 434
vendor lists, 7,350 items and their prices â€” and that file clears the rows it owns before inserting,
so a database that already has them can run it again without error. The inverse of every such
update is kept beside it in `data/sql/warband/` as a recovery script.

## Configuration and references

| Where | What |
| --- | --- |
| [`modules/mod-warband/conf/mod_warband.conf.dist`](modules/mod-warband/conf/mod_warband.conf.dist) | every Warband server option, installed as `bin/RelWithDebInfo/configs/modules/mod_warband.conf` |
| [Module README](modules/mod-warband/README.md) | each option in detail, and the command protocol |
| [Addon README](addons/Warband/README.md) | the client panel page by page, and the Dungeon Finder's All destinations tab |
| [Feature backlog](doc/Warband-Feature-Backlog.md) | what exists, what is wanted, and what was decided against |
| [Design record](doc/Warband-Design.md), [implementation policy](doc/Warband-Implementation-Policy.md) | the project's rationale and rules |
| [Module shortlist](doc/Warband-Server-Module-Shortlist.md), [module assessment](doc/Warband-Module-Assessment.md) | the research the module choices came from |
| [Setup and source layout](WowWarband-Setup.md) | local development workflow |

Runtime files â€” the built server, the client copy, extracted map data, database files and local
credentials â€” stay outside version control.

