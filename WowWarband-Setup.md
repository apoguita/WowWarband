# WowWarband source setup

This checkout is the source-first development tree for the local WotLK server. The AzerothCore Playerbot-compatible core is at the repository root; server modules, client addons, and the Keira3 editor source are pinned as Git submodules.

Runtime outputs, client assets, extracted server data, database files, and local configuration belong under the ignored `bin/`, `build/`, and `var/` directories and are not committed to GitHub.

The server build uses the Playerbot branch of `mod-playerbots/azerothcore-wotlk` with `mod-playerbots` master, plus the MultiBot bridge, ALE, and the progression module. The client addon source folders are `addons/MultiBot` and `addons/PlayerbotManager`. `tools/Keira3` is the database editor source; it is a separate desktop application.

Rebuilds must use the pinned module revisions and a clean database. Do not import database files from the previous packaged server.

## Local Windows runtime

`Start-WowWarband.bat` starts the local-only MySQL database when needed, then opens separate login-server and world-server consoles. Leave both consoles open during play. To stop cleanly, close the world-server console first, then the login-server console, and finally the minimized database window if you also want MySQL stopped. The extracted client and addon copies live in `var/client/`; generated `dbc`, `maps`, `vmaps`, `mmaps`, and camera data live in `var/data/`. Local database credentials are stored only in ignored runtime configuration.

The GitHub checkout contains source and pinned submodule revisions, not the compiled binaries, downloaded client, generated map files, or local database. A full checkout of all source uses `git clone --recurse-submodules`.

The tracked worldserver configuration template, the current local runtime config, and the runtime `.conf.dist` set `MaxPrimaryTradeSkill = 11`, allowing a character to learn all WotLK primary professions. The local worldserver was stopped during the change, so the setting will be used on its next start. The prior ignored config is backed up under `var/backups/ProfessionLimit-preinstall-*`.

ARAC is installed in this local runtime without a C++ build. Its world SQL is
applied, its three server DBC files are in `var/data/dbc/`, and its client patch
is `var/client/world of warcraft 3.3.5a hd/data/patch-z.mpq`. The SQL now
contains all 100 WotLK race/class combinations. The prior server DBC files are
backed up under ignored `var/backups/ARAC-preinstall-*`; the full database
backup made before the SQL import is also under `var/backups/`. The existing
client `patch-a.mpq` was not overwritten. Actual client patch loading and
character creation remain unverified. Using `patch-z.mpq` follows an
[AzerothCore custom-DBC guide](https://github.com/azerothcore/azerothcore-wotlk/discussions/4238),
but that reference does not verify this particular client's patch stack.

For a fresh local runtime, with the server and client stopped and a current
database backup made, repeat the integration from the pinned `modules/mod-arac`
source: apply `data/sql/db-world/arac.sql` to `acore_world`, copy
`patch-contents/DBFilesContent/{CharBaseInfo,CharStartOutfit,SkillRaceClassInfo}.dbc`
to `var/data/dbc/`, and copy `Patch-A.MPQ` to the client's `Data/` directory as
a free patch name (this runtime uses `patch-z.mpq`). Do not overwrite another
client patch. Verify the client/server DBC pairing and test character creation
for combinations such as Human Shaman and Undead Paladin before treating ARAC
as validated.

## Development workflow

- `Build-WowWarband.bat` performs the full server-and-tools build and configures
  discovered modules for dynamic linkage. The current `build` tree is configured
  with global `MODULES=dynamic`; all 13 discovered modules built as separate
  DLLs, and `worldserver` and `authserver` completed successfully in
  `RelWithDebInfo`. The shared-core/dynamic-module mode is experimental in
  AzerothCore.
- `Configure-WarbandModules.bat` (no arguments) can update an existing CMake
  configuration to dynamic linkage without compiling.
  `Build-WarbandModules.bat <module-folder> [<module-folder> ...]` builds and
  installs the named dynamic module DLL targets. It refuses to run unless the
  global CMake cache is dynamic. The worldserver loader discovers `mod_*.dll`
  files in its `scripts/` directory, so adding a module does not require
  regenerating an embedded DLL list or relinking `worldserver`.

  **Runtime activation is not yet verified:** the compiled servers have not
  been started. Core or loader changes still require rebuilding and restarting
  the server; changes isolated to one dynamic module can use the module-only
  helper. A module may still need separate SQL, configuration, or client assets.
- ALE loads project-owned scripts from `scripts/lua/`; `wowwarband_smoke_test.lua` is a harmless startup test. Keep custom script filenames unique.
- The BMAH backport source is pinned under
  `extras/Black-Market-Auction-House/`. ALE is enabled and the local runtime
  script path points to `scripts/lua/`, so the script/addon could be deployed
  without a C++ build. It remains inactive: its configured test NPC entry
  `2069430` is absent from the local world data, and no NPC creation/spawn SQL
  is included. The script handles bids on configured offers, not player
  listings/sales, so the current direction is to hold it inactive until both
  buying and selling are supported. A dedicated NPC/client setup will then be
  needed; loading the server script creates a character-database table and
  starts auction timers.
- `Open-Keira3.bat` opens the locally installed Keira3 3.10.5 release. Its source remains pinned under `tools/Keira3/`. Connect to the local MySQL instance and edit `acore_world`; keep credentials out of project files and Git.
- `Backup-WowWarband.ps1` backs up all four AzerothCore databases to ignored `var/backups/`. `Test-WowWarband-Backup.ps1` creates a backup, restores it to an isolated temporary MySQL instance, compares table counts, and removes the scratch instance only after a successful comparison.

The initial clean backup has been restored and verified. A reversible transaction test also confirmed that a temporary world-data edit can be rolled back without leaving a change in the game database.
