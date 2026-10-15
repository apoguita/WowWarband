# WowWarband source setup

This checkout is the source-first development tree for the local WotLK server. The AzerothCore Playerbot-compatible core is at the repository root; server modules, client addons, and the Keira3 editor source are pinned as Git submodules.

Runtime outputs, client assets, extracted server data, database files, and local configuration belong under the ignored `bin/`, `build/`, and `var/` directories and are not committed to GitHub.

The server build uses the Playerbot branch of `mod-playerbots/azerothcore-wotlk` with `mod-playerbots` master, plus the MultiBot bridge, ALE, and the progression module. The client addon source folders are `addons/MultiBot` and `addons/PlayerbotManager`. `tools/Keira3` is the database editor source; it is a separate desktop application.

Rebuilds must use the pinned module revisions and a clean database. Do not import database files from the previous packaged server.

## Local Windows runtime

`Start-WowWarband.bat` starts the local-only MySQL database when needed, then opens separate login-server and world-server consoles. Leave both consoles open during play; close the world-server console first to stop it cleanly. The extracted client and addon copies live in `var/client/`; generated `dbc`, `maps`, `vmaps`, `mmaps`, and camera data live in `var/data/`. Local database credentials are stored only in ignored runtime configuration.

The GitHub checkout contains source and pinned submodule revisions, not the compiled binaries, downloaded client, generated map files, or local database. A full checkout of all source uses `git clone --recurse-submodules`.
