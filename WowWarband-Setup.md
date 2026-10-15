# WowWarband source setup

This checkout is the source-first development tree for the local WotLK server. The AzerothCore Playerbot-compatible core is at the repository root; server modules, client addons, and the Keira3 editor source are pinned as Git submodules.

Runtime outputs, client assets, extracted server data, database files, and local configuration belong under the ignored `bin/`, `build/`, and `var/` directories and are not committed to GitHub.

The server build uses the Playerbot branch of `mod-playerbots/azerothcore-wotlk` with `mod-playerbots` master, plus the MultiBot bridge, ALE, and the progression module. The client addon source folders are `addons/MultiBot` and `addons/PlayerbotManager`. `tools/Keira3` is the database editor source; it is a separate desktop application.

Rebuilds must use the pinned module revisions and a clean database. Do not import database files from the previous packaged server.

## Local Windows runtime

`Start-WowWarband.bat` starts the local-only MySQL database when needed, then opens separate login-server and world-server consoles. Leave both consoles open during play. To stop cleanly, close the world-server console first, then the login-server console, and finally the minimized database window if you also want MySQL stopped. The extracted client and addon copies live in `var/client/`; generated `dbc`, `maps`, `vmaps`, `mmaps`, and camera data live in `var/data/`. Local database credentials are stored only in ignored runtime configuration.

The GitHub checkout contains source and pinned submodule revisions, not the compiled binaries, downloaded client, generated map files, or local database. A full checkout of all source uses `git clone --recurse-submodules`.

## Development workflow

- Rebuild the server and tools with `Build-WowWarband.bat`. It uses the installed Visual Studio toolchain, Boost 1.83, OpenSSL, and MySQL client libraries, and installs to the ignored `bin/RelWithDebInfo/` directory.
- ALE loads project-owned scripts from `scripts/lua/`; `wowwarband_smoke_test.lua` is a harmless startup test. Keep custom script filenames unique.
- `Open-Keira3.bat` opens the locally installed Keira3 3.10.5 release. Its source remains pinned under `tools/Keira3/`. Connect to the local MySQL instance and edit `acore_world`; keep credentials out of project files and Git.
- `Backup-WowWarband.ps1` backs up all four AzerothCore databases to ignored `var/backups/`. `Test-WowWarband-Backup.ps1` creates a backup, restores it to an isolated temporary MySQL instance, compares table counts, and removes the scratch instance only after a successful comparison.

The initial clean backup has been restored and verified. A reversible transaction test also confirmed that a temporary world-data edit can be rolled back without leaving a change in the game database.
