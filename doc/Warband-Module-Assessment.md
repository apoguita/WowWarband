# Warband module assessment

**Research snapshot: 2026-10-15.** This assessment preserves research into
third-party modules and addons. It is a technical reference for deciding what
to implement in WoW Warband-owned server code and client UI, and for separately
evaluating any proposed dependency. A candidate is not a generic API or an
automatic installation/build task. Some candidates are pinned as source, but
none is thereby considered selected, built, enabled, database-installed, or
gameplay-verified. See the
[implementation policy](Warband-Implementation-Policy.md).

## How to read this document

* **Source staged** means a pinned upstream source is present in this checkout; it is not a
  compatibility or runtime-success claim.
* **Promising candidate** means the upstream source appears to be a real module with a defined
  purpose that could support Warband. It is _not_ confirmed compatible with this Playerbot fork.
* **Blocked or not suitable as-is** means a known dependency, core patch, incompatible goal, or
  explicit limitation prevents treating it as a ready candidate.
* **Reference, not a solution** means it contains ideas or code worth studying but does not solve
  the stated Warband requirement.

The only meaningful definition of “working here” is: it compiles against this checkout, starts,
and passes a focused in-game test. No item below has that status yet.

## Overlap map

| Need | Overlapping options | What is distinct |
|---|---|---|
| Collecting loot | AoE Loot, E Interact, Auto Gather | AoE Loot consolidates nearby corpse loot. E Interact reduces clicking for a single interaction. Auto Gather handles gathering/skinning nodes, not general party loot routing. They can coexist but should not be mistaken for a distribution system. |
| Deciding who receives loot | Shared Loot, Quest Loot Party personal mode, Playerbot/MultiBot loot controls, Bot Quiet Rolls | Shared Loot removes the roll method; it does not assign an item to the right follower. Quest Loot Party personal mode gives every eligible member the same qualifying loot, not a role-aware assignment. Quiet Rolls only hides bot-pass chat lines. The existing Playerbot/MultiBot controls remain the first manual-routing capability to validate. |
| Keeping follower bags unobtrusive | Bot Inventory Master, Shared Gold, one automatic-selling module, AutoSort | These solve different parts of inventory pressure. Bot Inventory Master provides the required server-side authority over a follower's equipment and underlying bags; Shared Gold centralizes money; selling removes junk; AutoSort only rearranges bags. Bot Inventory Master can support an equipment-first player-facing experience even though the engine must retain bags underneath. |
| Automatic junk selling | Junk to Gold Plus **or** Auto Sell Grey | They overlap. Do not combine them. Auto Sell Grey also carries a core patch and an Eluna dependency, whereas Junk to Gold Plus is a conventional C++ module. |
| Experience and catch-up | Core rates, Individual Rates, XP Dynamic, Random-Bot Sync | Individual Rates and XP Dynamic can become competing XP/rate authorities. XP Dynamic's account-alt bonus is keyed to account characters and max-level characters, not the level gap between an owned follower and current leader. Random-Bot Sync is for random bots and protects party/owned bots, so it cannot catch up Warband followers. No reviewed candidate currently implements the desired leader-relative curve. |
| Account-wide progression | AccountWide, existing account-wide/ALE-style functionality | AccountWide shares selected account systems but intentionally skips Playerbots. It is not campaign-quest synchronization and cannot bring a newly recruited follower through a story. |
| Dungeon leadership | Dungeon Clear **or** Dungeon Lead | Both make a tank bot lead the group through dungeons. They are alternatives for an optional assisted-dungeon mode, not parts of the leader-paced follower model. |
| Raids and five-person adaptation | Raid Clear, Optimal Bot Raid, content downscaling | The two raid modules teach or organize ordinary bot raids. Neither turns raid encounters into five-member content. Downscaling is a separate design and technical problem. |
| Appearance | standard Transmog **or** Retail Transmog Plus | Both own transmogrification. The retail-style option adds account-wide collections, outfits, and client UI; it should not be combined with standard Transmog. |

## Source staged in this checkout

The following are pinned third-party source references for feature and
compatibility research. None of these newly staged C++ candidates has been
compiled, configured, enabled, or tested in-game. This does not refer to the
already-running baseline modules (Playerbots, ALE, MultiBot Bridge, and
progression). ARAC is the exception among non-C++ integrations: its world SQL
and server/client DBC assets are installed in the local runtime, but the
character-creation flow has not been verified in-game. The BMAH script/addon
remains inactive and undeployed.

| Source | What is present | Integration boundary |
|---|---|---|
| `mod-auto-gather` | C++ module and config template | Its PlayerScript updates every player; there is no Playerbot exclusion. It only performs work when a character has mining, herbalism, or skinning. Keep follower professions out of scope and review whether a bot guard is needed. |
| `mod-aoe-loot` | C++ module and world DB module-string SQL | Consolidates nearby corpse loot; does not route items to the right follower. Its SQL uses the `module_string` tables present in this checkout's world schema, not hard-coded core string IDs. |
| `mod-bot-inventory-master` | C++ command/protocol module, bundled client UI, and SQL aid | Supports online same-account bots. The UI includes equipment plus individual/party bag views and direct/bulk sell/destroy controls. It exceeds the desired equipment-only player-facing scope unless restricted; dangerous single-item actions are enabled by the supplied config defaults. The runtime has not received its UI or module. |
| `mod-junk-to-gold-plus` | C++ auto-sell module and config template | Protects quest-related items and gray usable upgrades. Its loot hook does not specifically exclude Playerbots; verify the recipient and payment behavior before enabling for followers. |
| `mod-shared-gold` | Playerbot-integrated C++ module and config template | Current core provides the script hooks it references, and the module uses Playerbot master ownership. AH proceeds are explicitly outside its coverage. |
| `mod-arac` | ARAC SQL, server DBC content, client MPQ source | Local data integration applied without a C++ build. World SQL added all 100 WotLK race/class combinations; server DBC files were replaced with a backup retained under ignored `var/backups/`; client MPQ was installed as `patch-z.mpq`, leaving the existing `patch-a.mpq` untouched. Actual client patch loading and character creation remain unverified. |
| `mod-dead-means-dead` | C++ module and config template | Matches the requested in-instance creature-respawn behavior. Its README says active instances remain protected, but instance unload can restore original respawn timing. No `Instance.UnloadDelay` change is included or approved. |
| `DungeonRespawn` | Archived C++ module, config and character DB SQL | Matches the separate request to return the player to the dungeon entrance after death. Keep as a source candidate; it is archived and uncompiled against this fork. |
| `extras/Black-Market-Auction-House` | Eluna-style server script plus 3.3.5 client addon | Not activated. Its current NPC list contains test entry `2069430`, absent from the local world data; the source does not create or spawn that NPC. The local ALE code exposes the principal Lua APIs it calls, including player whisper event 19 and creature gossip, but runtime compatibility is untested because ALE diverges from standard Eluna. The addon TOC targets interface 30300 and depends on `Blizzard_AuctionUI`. Loading the script creates a character-database table and starts auction timers. |
| `mod-ah-bot` | Official AzerothCore C++ module source and world SQL | Source is pinned but inactive. It supports seller and buyer behavior independently, requires a configured account/character and world SQL, and documents minimum core commit `9adba48`, which is an ancestor of this checkout. It has a `src/` tree and is discovered by this branch's module scanner; a per-module `CMakeLists.txt` is not required for source discovery. |

The source directories are ignored by the generic `modules/*` rule, so each
module is recorded as a Git submodule pointer in `.gitmodules` and the index.
The module loader discovers C++ modules by the presence of `src/`; ARAC has no
`src/` directory and is therefore not part of CMake's module build list.
The local runtime's module-config directory currently contains configs only
for the existing baseline modules; no newly staged candidate has been
configured for runtime use.

A read-only loader scan found that each staged C++ candidate exposes the
module-specific `Add…Scripts` entry point expected by this checkout's current
loader template; none contains the legacy `AC_ADD_SCRIPT_LOADER` or
`AC_ADD_SCRIPT` macros that CMake uses to force deprecated-loader modules to
static linkage. This is source-level evidence only: it does not establish
compile compatibility or prove that separately built DLL entry points are
loaded by the running server.

## Existing non-build integration status

This status records data/configuration work already performed without a C++
build. “Installed” below means files or data are in place; it does not imply
in-game verification or authorize additional integration work.

| Work | Current status | What remains |
|---|---|---|
| ARAC race/class combinations | Installed locally without a C++ build: world SQL contains all 100 WotLK race/class combinations, matching server DBCs are in `var/data/dbc/`, and the client patch is `patch-z.mpq`. | Verify the client loads the patch and character creation offers combinations such as Human Shaman and Undead Paladin. |
| Profession availability | The tracked worldserver template, local runtime config, and its generated `.conf.dist` now set `MaxPrimaryTradeSkill = 11`, allowing all WotLK primary professions; secondary professions are not limited by this setting. | Confirm in-game after the next worldserver start. |
| BMAH script and client UI | Intentionally held inactive per current direction. Its Lua source and client addon are present only under `extras/Black-Market-Auction-House`. The local ALE API has matching principal function names, but compatibility is not verified. | Add/support player buying and selling before activation; then resolve NPC/client setup and review its character-DB table/timer side effects. |
| Shortlisted C++ modules | Source is pinned, but none of the new C++ modules is enabled in the current runtime. | If a specific candidate is later selected, review its SQL/configuration and prepare a scoped build estimate for explicit user approval before compiling or enabling it. Candidates include AoE Loot, Auto Gather, Bot Inventory Master, Junk to Gold Plus, Shared Gold, Dead Means Dead, DungeonRespawn, and normal-AH `mod-ah-bot`. |
| `mod-warband`: binding-free items | Implemented in the module and compiled into the current build. There is no core item-layer change: nothing under `src/` was modified for it, and the earlier documents that described accompanying core changes were describing a layer that does not exist in this repository. | Verify the behaviour in game: newly acquired, already-owned, quest, equipped, enchanted, mailed and group-roll items. |

The BMAH Lua script is a possible no-C++-build integration, but the user has
chosen to hold it inactive until it supports both buying and selling. Its
current feature is bidding on configured offers, not player selling, and it
still needs a working NPC/client setup. Its compatibility with this ALE build
is not verified. This is a feature-fit and integration-readiness deferral, not
a C++ build requirement.

No build or CMake reconfiguration was run for this research snapshot. A module
being source-staged, or its SQL/config being present, must not be reported as
active until the required approved build and relevant runtime checks.

## Integration requirements recorded for reference

These are source-reviewed deployment requirements, not applied setup steps or
an approved integration plan.
The only newly applied module SQL/data integration is ARAC; no deferred
candidate config or SQL has been copied/imported into the runtime.

- **Auto Gather:** copy `modules/mod-auto-gather/conf/mod_auto_gather.conf.dist`
  to `bin/RelWithDebInfo/configs/modules/mod_auto_gather.conf`. No SQL file is
  shipped. Its defaults enable automatic gathering; source updates run for all
  players and have no explicit Playerbot exclusion, so do not enable for
  followers without deciding that behavior.
- **AoE Loot:** config is
  `modules/mod-aoe-loot/conf/mod_aoe_loot.conf.dist`, copied to
  `bin/RelWithDebInfo/configs/modules/mod_aoe_loot.conf`. World
  string/localization SQL is
  `modules/mod-aoe-loot/data/sql/db-world/base/aoe_loot_module_string.sql` and
  targets `module_string` / `module_string_locale`. Import only after the
  module is selected and included in the build/database update path.
- **Bot Inventory Master:** config is
  `modules/mod-bot-inventory-master/conf/BotInventoryMaster.conf.dist`, copied
  to `bin/RelWithDebInfo/configs/modules/BotInventoryMaster.conf`. The source
  creates two tables in `acore_characters` and one exclusion table in
  `acore_world` on startup; the bundled
  `modules/mod-bot-inventory-master/sql/bot_inventory_master_tables.sql` is
  described as a manual inspection/bootstrap aid, not an automatic SQL
  migration. The matching client UI source is
  `modules/mod-bot-inventory-master/BotInventoryMasterUI/`; it is not copied to
  the local client's AddOns directory. Its TOC targets Interface 30300 and says
  version 0.9, while its own README says v0.8, so confirm client/protocol
  compatibility before deployment. The UI exposes equipment and party-bag
  management as well as direct/bulk sell and destroy. Its config defaults
  enable unrestricted single-item selling and destruction, including quest
  items, while requiring no confirmation. Override
  `BotInventoryMaster.Danger.AllowAnySell`,
  `BotInventoryMaster.Danger.AllowAnyDestroy`, and
  `BotInventoryMaster.Danger.RequireConfirm` before enabling; this is not a
  selected policy.
- **Junk to Gold Plus:** copy
  `modules/mod-junk-to-gold-plus/conf/mod_junk_to_gold_plus.conf.dist` as
  `bin/RelWithDebInfo/configs/modules/mod_junk_to_gold_plus.conf`. No SQL file
  is shipped. Auto-sale is enabled by default; confirm how the loot hook behaves
  for follower loot and where its sale proceeds go before activating it
  alongside other loot/money modules.
- **Shared Gold:** copy
  `modules/mod-shared-gold/conf/mod_shared_gold.conf.dist` as
  `bin/RelWithDebInfo/configs/modules/mod_shared_gold.conf`. No SQL file is
  shipped. It does not route Auction House proceeds and does not recognize Junk
  to Gold Plus direct money credits as vendor sales.
- **Dead Means Dead:** config is
  `modules/mod-dead-means-dead/conf/mod_dead_means_dead.conf.dist`, copied to
  `bin/RelWithDebInfo/configs/modules/mod_dead_means_dead.conf`; its shipped
  world SQL writes a localized `acore_string` row at entry `35410`. Review that
  entry against the local database before import. Instance unload restores
  original creature respawn timing; changing `Instance.UnloadDelay` is a
  separate, unapproved configuration choice.
- **DungeonRespawn:** copy
  `modules/DungeonRespawn/conf/dungeonrespawn.conf.dist` to
  `bin/RelWithDebInfo/configs/modules/dungeonrespawn.conf`; its character DB
  assets are a base schema and dated update under
  `modules/DungeonRespawn/data/sql/db-characters/`. The repository is archived;
  review the SQL against the current character schema and module source before
  applying.
- **Official `mod-ah-bot`:** config is
  `modules/mod-ah-bot/conf/mod_ahbot.conf.dist`, copied to
  `bin/RelWithDebInfo/configs/modules/mod_ahbot.conf`; its three shipped SQL
  files are under `modules/mod-ah-bot/data/sql/db-world/`. The main schema file
  drops and recreates `mod_auctionhousebot`, so inspect/backup the world DB
  before a first import and do not rerun it over settings you want to preserve.
  Configure a dedicated bot account/character; seller and buyer are both
  disabled by default. A minimal solo-market starting option is to enable
  `AuctionHouseBot.EnableSeller` and `AuctionHouseBot.EnableBuyer` and leave
  the remaining price/quota defaults alone until they prove unsuitable. The
  seller seeds listings and the buyer can purchase player listings; this is an
  evaluation profile, not applied configuration or a final economy decision.
- **`mod-warband` binding-free items:** no config or SQL is needed and no core
  change is involved: the behaviour is implemented entirely in the module, so any
  build that contains `mod-warband` already has it.
- **BMAH backport:** deployment requires the server Lua script and its matching
  3.3.5 client addon. The Lua creates its character DB table and starts timers
  when loaded. A dedicated NPC entry/placement is still missing, and the source
  only supports bidding on configured offers—not player listings/selling—so it
  does not yet satisfy the requested BMAH buy-and-sell behavior.

The existing `build/CMakeCache.txt` was inspected read-only: the global default
is still `MODULES=static`, and CMake knows only the previously configured
modules (ALE, MultiBot Bridge, Playerbots, progression, and the in-house
`mod-warband` module). `mod-warband` is built into the current runtime; renaming
its directory to `mod-warband` changes the generated entry point
(`Addmod_warbandScripts`), so the next build has to be a CMake configure followed
by a build. The core item layer the earlier documents described alongside it does
not exist in `src/`, so no core change is waiting on a rebuild. Newly pinned
candidate sources have not been configured or built. The eventual
user-supervised configure/build must deliberately select the desired modules and
linkage; pinning source alone does not add a module to the current build.

CMake has logic to produce separate shared-library targets for modules
configured as `dynamic`, and the generated DLL loader exports module entry
points. However, in this checkout's worldserver path, `Main.cpp` registers the
generated `AddModulesScripts` callback and `ScriptMgr::Initialize()` invokes
that callback; a runtime path that discovers and invokes the separately built
DLL entry points was not found in the source reviewed. The official
[AzerothCore changelog](https://www.azerothcore.org/wiki/changelog) describes
dynamic script DLL support, but that alone does not confirm runtime loading in
this Playerbot fork. Therefore `Build-WarbandModules.bat` is an unverified
build/install convenience, not proof that a DLL-only module will activate. Any
approved build must verify module discovery and startup before relying on
incremental DLL-only additions. Core changes, loader changes, legacy-loader
modules forced to static, and separate database/config/client requirements
also remain outside a DLL-only path.

## Assessment by area

### Loot and follower belongings

| Item | Status | What research establishes | Warband fit / limit |
|---|---|---|---|
| `mod-aoe-loot` | Promising candidate | Official module, current C++ source, group support, per-player toggle, configured range, and a combined loot window. | Good collection convenience. It intentionally does not decide which follower owns equipment. |
| `mod-shared-loot` | Promising candidate, but a policy choice | Forces Free-For-All and optionally pairs with the core's everyone-loots behavior. It explicitly does not rewrite loot distribution. | It removes rolls but does not supply role-aware allocation. With duplicated “everyone loot,” it may create more follower bags, the opposite of the equipment-only goal. |
| `mod-quest-loot-party` (Nexartgroup fork) | Experimental candidate; not staged | The fork offers three toggles: share eligible quest objective items to group members who have and still need the quest; increase quest-drop chance when someone needs it; or give each eligible member a copy of the same qualifying corpse loot. Its README says the formerly required PR #16509 is obsolete because its hooks are now present in AzerothCore. It has only two commits on the repository page. | Its quest features still require per-character quest state and do not make followers eligible for leader-only completion/turn-in. Personal mode is not independent per-player loot: the corpse table rolls once and the same qualifying items are copied to all, risking multiplied supply and full follower bags. The local fork contains the needed player/global/misc script hooks, but module compilation and gameplay behavior are unverified. |
| `mod-shared-gold` | Promising candidate | Explicit Playerbot integration routes bot loot, vendor-sale, and quest-reward gold to the real master; it leaves AH proceeds and other ambiguous transfers alone. | A strong match for a leader-owned wallet if follower gold should be invisible. It is independent of item routing. |
| `mod-bot-inventory-master` | Promising candidate; UI is bundled but not deployed | The server module exposes same-account equipment and inventory commands. Its matching Interface 30300 addon currently includes equipment management, individual and party bag views, bulk cleanup, selling, and deletion. The addon README says v0.8 while its TOC says v0.9. | The closest existing candidate for equipment control and party-loot housekeeping, but its broad bag UI and destructive controls go beyond the intended equipment-only experience. The server config defaults are unsafe for hands-off use (unrestricted single-item sell/destroy and no confirmation). Keep the addon optional; first decide which controls are appropriate, reconcile version metadata, and verify its protocol with the pinned server module. |
| `mod-bot-quiet-rolls` | Conditional candidate | It keeps the normal roll outcome and only suppresses bot “passed” chat packets. Its README requires the current Playerbot fork's `WorldSession::IsHeadless()` support. | Useful only if normal rolls remain. It has no bearing on who receives a drop. |
| `mod-junk-to-gold-plus` | Source staged; candidate single auto-seller | Conventional C++ module that sells gray loot when looted while protecting quest items, quest-start items, active-objective items, and usable gray upgrades. Its hook does not explicitly exclude bots. | User prefers this over Auto Sell Grey. Verify bot recipient/payment behavior. Its direct `ModifyMoney` credit will not be recognized by Shared Gold's marked vendor-sale path, so that combination does not itself centralize the auto-sale proceeds. |
| `mod-autosell-grey` | Blocked / reference unless its patch is accepted | Lua/Eluna system with a small core patch to `Player::StoreLootItem()`, character SQL, and full-bag handling. It explicitly excludes bots. | Does not solve follower bags and requires a core patch, contrary to the modular direction. It should not be batched with Junk to Gold Plus. |
| `mod-autosort` | Low-risk convenience candidate | Inventory sorting only. | Leader quality of life; no follower routing or cleanup policy. |
| `mod-e-interact` | Promising convenience candidate | One action can interact, loot, gather, speak, accept/complete quests, and answer rolls. | Reduces friction and complements AoE Loot. It overlaps Auto Gather only for the manual gathering interaction. |
| `mod-auto-gather` | Source staged; bot-scope check needed | Automatic nearby mining, herbalism, and skinning, with range and safety options. Source runs its PlayerScript update on every player and does not contain a bot exclusion; gathering only runs when the character has the matching skill. | Useful for the leader. Do not give companions professions to enable it; if follower profession skills exist, assess whether a bot guard is needed. |

### Already requested baseline ideas

| Item | Status | What research establishes | Warband fit / limit |
|---|---|---|---|
| `mod-arac` | Separate data/client-patch project, not a C++ module | It enables race/class combinations using world data plus matching server/client DBC data and a client `Patch-A.MPQ`. | It is independent of the other shortlisted modules, but client/server data must remain matched. It belongs in a client-patch compatibility review, not a C++ module build batch. |

### Economy and Auction House

| Item | Status | What research establishes | Warband fit / limit |
|---|---|---|---|
| Existing Playerbots AH code | Not an active AH feature | The checked-out `LootAction.cpp` contains an `AuctionItem` helper, but it is block-commented; no active Playerbots AH configuration option was found. | The existing Playerbots build does not remove the need for a separate normal-AH buy/sell module or Warband implementation. |
| `mod-ah-bot` | Source pinned; inactive and unbuilt | Official AzerothCore module; upstream says seller and buyer operations can be enabled independently. It requires a configured player account/character and world-database SQL. Its minimum required core commit `9adba48` is an ancestor of this checkout. | A concrete normal-AH buy/sell candidate. Its quota/price controls are extensive, but can be configured simply; no AH settings or SQL have been applied, and no build/runtime validation has occurred. It does not handle BMAH. |
| `mod-ah-bot-plus` | Not staged; source alternative | Another module that provides seller listings and an optional buyer for player listings. Its documented minimum core commit is an ancestor of this checkout. | Keep as an alternative to the official `mod-ah-bot`; do not include both because they overlap as AH market bots. It does not supply BMAH behavior. |
| `Black-Market-Auction-House` | Source pinned; intentionally held inactive | Script and client UI provide bidding on configured offers, outbid refunds, and mail delivery. The source's test NPC entry `2069430` is absent from the local world data, and no NPC creation/spawn SQL is included. Local ALE exposes the principal API names used by the script, but its Eluna-origin runtime behavior has not been tested. | The user chose to defer activation until both buying and selling are supported; the current source does not support player listings/selling. A dedicated NPC and placement remain setup work; loading the script also creates a character DB table and starts auction timers. |

### Growth, campaign progress, and catch-up

| Item | Status | What research establishes | Warband fit / limit |
|---|---|---|---|
| `mod-individual-rates` | Promising candidate | Mature-looking C++ module providing account-first or per-character XP, reputation, skill, drops, money, and caps. Its own documentation warns that core rates multiply with its rates. | A good **control surface** for the leader's pacing, but it does not synchronize followers. If selected, it should be the only general rate authority. |
| `mod-xp-dynamic` | Reference only; not staged | Its upstream README describes per-level/source XP rates and an account-alt progression bonus that applies below the highest-level character on the account, with the multiplier based on how many characters reached the server cap. It also includes gold/reputation rates, skill-XP bonus rolls, and optional class fixes for ARAC. It requires a character-database account-table SQL update and a C++ rebuild. | It does not describe or implement an XP multiplier based on a follower's gap from the active leader, and does not establish support for owned AltBots. It is not the requested catch-up solution. It could only be considered separately for general rate controls, where it overlaps `mod-individual-rates`; a custom Playerbot-aware rule remains the likely route for leader-relative catch-up. |
| Core `Rate.XP.*` settings | Built-in AzerothCore configuration, no module | The tracked worldserver template exposes separate multipliers for kill, quest, exploration, pet, and battleground XP; its defaults are 1x. | This is sufficient for a simple server-wide XP pace adjustment. It does not provide a character-specific or leader-relative follower catch-up curve. |
| `mod-accountwide` | Promising but not campaign sync | C++ replacement for ALE-style sharing of achievements, cosmetics, reputation, currencies, and PvP. It explicitly detects and skips Playerbots. | Can make account progression feel shared, but cannot transfer campaign quest states to followers. Its broad sharing may be more than the current scope; each feature needs an explicit enable/disable decision. |
| `mod-rndbot-sync` | Reference, not a solution | It synchronizes **random** bots around the highest online real player and expressly excludes a player's own/party bots. | Its protected exclusions mean it will not catch up Warband followers. It is useful as a code/design reference only. |

### Dungeons, raids, recovery, and difficulty

| Item | Status | What research establishes | Warband fit / limit |
|---|---|---|---|
| `mod-dead-means-dead` | Promising candidate; compatibility and instance lifecycle need checking | Its upstream README says creature respawns are disabled by default in dungeons and raids, with configurable respawn behavior. If an instance unloads, its respawn time can be reset to the original value; it says active instances with players remain protected. | This addresses mobs respawning during an instance run. It does **not** change where the player respawns after death. The README suggests `Instance.UnloadDelay=0` as a workaround, but that server-config change has operational implications and is not approved or selected. Verify exact behavior against this fork before deciding. |
| `DungeonRespawn` | Conditional; archived | C++ death-recovery module with character data/configuration, but its repository is archived. | A contained recovery convenience. Test source compatibility before it is considered; if it does not compile, reimplementing this narrow behavior may be cleaner than reviving an archived module. |
| `mod-dungeon-clear` | Promising alternative | Established Playerbot extension that has a tank bot route, pull, loot, rest, and handle many dungeon events. | Optional “let the tank lead” play mode. It changes the intended player-led campaign feel and must be chosen instead of Dungeon Lead, not alongside it. |
| `mod-playerbots-dungeon-lead` | Early-stage alternative | Standalone Playerbot module whose README labels it work in progress; its own live coverage is partial and it says recent runs with a real player need further validation. | Also an optional bot-led 5-man dungeon mode; do not batch it with Dungeon Clear. |
| `mod-raid-clear` | Reference for later | Teaches Playerbots mechanics for particular normal raid encounters; it expects raid roles such as multiple tanks. | Valuable implementation reference. It does not reduce raid group size or retune the encounter for leader + four followers. |
| `mod-optimal-bot-raid` | Reference for later | Orchestrates a conventional Playerbot raid composition. | Same mismatch: ordinary raids rather than five-member adaptations. |
| `mod-open-world-party-scaling` | Not suitable as-is | Its stated purpose is to **increase** open-world combat difficulty for parties. | This is the inverse of the desired ability to downscale world events and raid content to the five-member Warband. Keep as a reference only; do not add it for that purpose. |

### Appearance, builds, and solo convenience

| Item | Status | What research establishes | Warband fit / limit |
|---|---|---|---|
| `mod-transmog` | Promising candidate | Standard official AzerothCore transmog implementation. | Direct fit for appearance control. Alternative to Retail Transmog Plus. |
| Retail Transmog Plus | Conditional alternative | Adds an account-wide collection, sets/outfits, collection from loot/disenchant, and a client UI. | A broader collection game, not merely appearance control. Select instead of, not alongside, standard Transmog; client work is required. |
| `mod-talentbutton` | Promising convenience candidate | Makes build experimentation easier through early dual spec and remote talent reset. | Directly supports player-shaped companion builds, but AltBot use needs a focused test. |
| No Hearthstone Cooldown | Convenience candidate | Removes one travel timer. | No conflict, but deliberately changes travel pacing. |
| All Flightpaths | Convenience candidate | Unlocks travel nodes automatically. | Removes map discovery; a preference decision rather than a systems requirement. |
| Quest Radar | Deferred | Server support exists, but the useful presentation requires its matching client addon. | Leave for the client-addon phase. It does not solve quest synchronization. |
| Warband Camp | Later design option | Account-wide camp with utility services, rest, and presentation. | Thematic, but expands beyond the defined combat-follower scope. Keep optional. |
| Forever Journal | Deferred convenience | Realm-data journal with a client component. | Useful reference/planning UI later; no companion-system effect. |
| Boss Archive | Later economy/collection option | Recovers or archives boss loot. | Changes farming and gear acquisition. It should follow, not decide, the loot model. |

## What should be implemented by Warband itself

No shortlisted module supplies the three central behaviors below without changing the intended experience.

1. **Follower campaign catch-up.** A follower always begins at level 1 and should receive a level-gap XP multiplier until it reaches the leader. Existing account-wide and random-bot modules do not perform this for owned AltBots. XP Dynamic is account/max-level based, not leader-gap based; no reviewed candidate currently supplies the requested rule, so a Warband-specific Playerbot-aware implementation is the likely route.
2. **Leader-paced quest completion.** The desired rule is stronger than shared quest-item loot: the leader fulfills objectives, then followers can complete/claim an appropriate result without independently grinding counters. This needs Playerbot/quest-state investigation and very likely a focused Warband module or extension.
3. **Five-member adaptations for raids and large world events.** The goal is downscaling content for leader + four followers, not making the outdoor world harder for a party. The selected raid/party-scaling modules do not do this. A future Warband solution likely needs encounter-specific data/rules plus a narrowly scoped scaling mechanism.

Potential small fallback: if the archived DungeonRespawn module is incompatible, its isolated death-recovery behavior is a reasonable small Warband module rather than a reason to keep an old external dependency alive.

## Open research and design questions

1. If a third-party dependency is proposed, finish source-level compatibility checks and distinguish downloaded source from compiled/runtime behavior.
2. Resolve the actual loot-policy alternatives that cannot safely be enabled together, especially FFA versus normal rolls and automatic gray cleanup versus recipient-aware equipment handling.
3. The retained research compares the pinned official normal-AH bot with the unpinned `mod-ah-bot-plus` alternative. If either is proposed, select at most one and review its integration scope; no build is authorized by this note. Review the BMAH Lua/client-addon source separately; it is bid-only as documented and needs player-listing support to meet the confirmed Black Market buy-and-sell goal.
4. Keep the custom follower level-gap catch-up, leader-paced quest completion/rewards, and five-member raid adaptations as documented Warband work.
5. If an implementation is later selected, review its SQL/config/client-data
   requirements as part of its scoped estimate and approval request. ARAC's SQL
   and client/server data are the documented non-C++ exception already applied
   to the local runtime; do not mistake that for completed in-game validation.

Earlier notes deferred builds to a supervised final step. That historical note
is not approval to build now. Keep this research as reference, and label
unresolved behavior as unverified. Any proposed build or integration must
follow the current [implementation policy](Warband-Implementation-Policy.md).
Some candidates remain alternatives because they encode different game rules
or lack a required piece—not because their source cannot be downloaded.
