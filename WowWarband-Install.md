# WoWWarband: install the release from scratch

This guide installs a precompiled WoWWarband release — the zip published on GitHub — on a clean
Windows machine and gets you in game. It covers the prerequisites, the download, the database, the
map data, the first start and the client.

It does not cover building from source; that is the other path, described in
[WowWarband-Setup.md](WowWarband-Setup.md).

---

## 1. What you are installing

A WoWWarband release is a ready-made **server** plus the **client addons**, for one player who runs
a party of five: themselves and four AI companions. It targets World of Warcraft **3.3.5a, build
12340** — the same client the whole project is built on.

The zip contains:

* the server programs and their configuration (`bin\`),
* the SQL that builds the server databases (`data\sql\`),
* the client addons (`Interface\AddOns\`),
* licence texts and a manifest.

It does **not** contain:

* the WoW client (never redistributable — you supply your own),
* the map/navmesh data extracted from the client (you generate it, step 6),
* a database — the databases are built from the SQL with `dbimport.exe`.

---

## 2. Prerequisites

| Requirement | Details | Check |
| ----------- | ------- | ----- |
| Windows 10/11, 64-bit | The release is `win64` only. | `[Environment]::Is64BitOperatingSystem` |
| MySQL Server 8.0+ | 8.4 LTS is what the release was built against. Community Server is fine. | `mysql --version` |
| WoW 3.3.5a client, build 12340 | Your own copy; not shipped. `Data\` feeds the extractors. | `Data\enUS\` present |
| VC++ 2015-2022 x64 redistributable | Dynamic C runtime; usually already installed. | `vcruntime140.dll` in System32 |
| ~10 GB free disk space | Zip 183 MB, unpacked ~0.6 GB, map data ~8 GB, databases 1-2 GB. | `Get-PSDrive C` |
| Windows PowerShell 5.1 | Built in; only needed for the optional helpers below. | `$PSVersionTable.PSVersion` |

### 2.1 Install MySQL Server

1. Download the **MySQL Community Installer** from `dev.mysql.com/downloads/installer/`.
2. Choose **Server only** (or Custom, MySQL Server 8.4).
3. Set port **3306**, bind **127.0.0.1**, and choose a root password you remember.
4. Keep the Windows service enabled.
5. The `bin` folder (e.g. `C:\Program Files\MySQL\MySQL Server 8.4\bin`) is **not on `PATH`** by
   default — note where it is; you will name `mysql.exe` in a config file later.

### 2.2 Create the database account

The shipped configuration expects a MySQL user **`acore`** with password **`acore`**. Create it once
and no credentials need editing:

```sql
CREATE USER 'acore'@'localhost' IDENTIFIED BY 'acore';
GRANT ALL PRIVILEGES ON *.* TO 'acore'@'localhost' WITH GRANT OPTION;

CREATE USER 'acore'@'127.0.0.1' IDENTIFIED BY 'acore';
GRANT ALL PRIVILEGES ON *.* TO 'acore'@'127.0.0.1' WITH GRANT OPTION;

FLUSH PRIVILEGES;
```

Run it with `mysql -u root -p` (type the root password from step 2.1).

Prefer your own login? Skip this and edit the `DatabaseInfo` lines in step 4.1 instead.

---

## 3. Download the release

1. Open **https://github.com/apoguita/WowWarband/releases**.
2. Download the newest stable asset, named like `wow-warband-0.6.0-win64.zip` (183 MB).
3. Optionally verify it (hash is in the release notes; 0.6.0 is
   `b0e0f409183bfa803faf61b57a826591cb8bb7745577043b072eff5a4eee8291`):

   ```powershell
   Get-FileHash .\wow-warband-0.6.0-win64.zip -Algorithm SHA256
   ```

4. Extract the zip to **the folder that will be the server**, for example `C:\WoWWarband`.

   * Avoid `Program Files`: the servers write logs and data next to themselves.
   * Keep the path short; spaces should be quoted wherever you pass the path.

After extraction the folder contains:

```
C:\WoWWarband\
    bin\              server programs, extractors, configuration
    data\sql\         database schema and updates
    Interface\AddOns\ Warband, MultiBot, PlayerbotManager
    scripts\          helper scripts (see the note in step 7)
    LICENSE, MANIFEST.txt
```

---

## 4. Point the package at your machine

The binaries were built on the author's machine, so a few built-in defaults still name **that**
machine. Each one has a config key that overrides it. Edit these three files (Notepad is fine):

* `C:\WoWWarband\bin\configs\dbimport.conf`
* `C:\WoWWarband\bin\configs\worldserver.conf`
* `C:\WoWWarband\bin\configs\authserver.conf`

Use forward slashes in paths (`C:/WoWWarband/data`).

### 4.1 Database connection — all three files

If you created the `acore` user in step 2.2, change nothing. Otherwise edit these lines in each
file to match your MySQL login (format: `host;port;user;password;database`):

```
LoginDatabaseInfo     = "127.0.0.1;3306;acore;acore;acore_auth"
WorldDatabaseInfo     = "127.0.0.1;3306;acore;acore;acore_world"
CharacterDatabaseInfo = "127.0.0.1;3306;acore;acore;acore_characters"
```

### 4.2 SQL source directory — all three files

`dbimport.exe` and both servers read the SQL from `data\sql`. Override the built-in path:

```
SourceDirectory = "C:/WoWWarband"
```

Without it, `dbimport.exe` stops with *"The given source directory … does not exist"*.

### 4.3 MySQL CLI path — all three files

The database updater shells out to the `mysql` command-line client:

```
MySQLExecutable = "C:/Program Files/MySQL/MySQL Server 8.4/bin/mysql.exe"
```

The zip ships a value naming the author's MySQL install — replace it with your path. Adjust the
version folder to what you installed (8.0 or 8.4). Alternatively, add MySQL's `bin` to the system
`Path` and leave the value empty.

### 4.4 Data directory — `worldserver.conf` only

`worldserver.exe` runs from `bin\`, so a relative `DataDir` would point inside `bin\`. Make it
absolute:

```
DataDir = "C:/WoWWarband/data"
```

### 4.5 What is already configured

`worldserver.conf` already has `Updates.EnableDatabases = 7` and `Updates.AutoSetup = 1`, and
`authserver.conf` has `Updates.EnableDatabases = 1`: the programs can create the databases and apply
the SQL themselves. Running `dbimport.exe` explicitly (step 5) still gives clearer error messages.

---

## 5. Create the databases

In a command prompt:

```bat
cd C:\WoWWarband\bin
.\dbimport.exe
```

* For each missing database it asks **`Do you want to create it? [yes (default) / no]:`** — press
  **Enter** three times (auth, characters, world). It creates the database, fills it from
  `data\sql\base`, then applies `data\sql\updates` and the module SQL under `data\sql\modules`.
* A clean run ends with **`Halting process...`** and no `update file(s) failed to apply` line.
* The first run takes a few minutes; output is also written to `bin\DBImport.log`.

Verify:

```powershell
& "C:\Program Files\MySQL\MySQL Server 8.4\bin\mysql.exe" -u acore -pacore -e "SHOW DATABASES LIKE 'acore%'"
```

You should see `acore_auth`, `acore_characters`, `acore_world`.

---

## 6. Generate the world data from your client

The server needs `dbc`, `maps`, `vmaps` and `mmaps` under `data\`, extracted from **your** client.
The examples use the client at `C:\World of Warcraft`; quote it exactly.

```bat
cd C:\WoWWarband\bin

:: 1. DBC files + terrain maps + camera files  ->  data\dbc, data\maps, data\Cameras
.\map_extractor.exe -i "C:\World of Warcraft" -o "C:\WoWWarband\data"

:: 2. Raw vmap geometry  ->  bin\Buildings
.\vmap4_extractor.exe -d "C:\World of Warcraft"

:: 3. Assemble the vmaps  ->  data\vmaps
.\vmap4_assembler.exe Buildings "C:\WoWWarband\data\vmaps"

:: 4. Build the navigation meshes  ->  data\mmaps  (run from data; reads maps\ and vmaps\)
cd C:\WoWWarband\data
..\bin\mmaps_generator.exe
```

Order matters: `mmaps_generator` needs both `maps` and `vmaps` beside it. It finds
`mmaps-config.yaml` in the `bin` folder automatically.

* Rough timings on a modern desktop: step 1 minutes; steps 2-3 ten to thirty minutes; step 4 the
  long one, from half an hour to over an hour depending on CPU cores.
* `vmap4_extractor.exe` refuses to run on a populated `bin\Buildings` it did not create; delete
  that folder and start over if you must re-run it.
* Upgrading from an older Warband install? Its `data\` folder is the same format — copy it in
  instead of re-extracting.

When done, `C:\WoWWarband\data` contains `dbc\`, `maps\`, `vmaps\`, `mmaps\` (and `Cameras\`).

---

## 7. Start the server

Open **two** consoles, both in `C:\WoWWarband\bin`:

```bat
cd C:\WoWWarband\bin
start authserver.exe      :: login server, port 3724
start worldserver.exe     :: world server, port 8085  (start it second)
```

Leave both windows open. The world server takes several minutes on first start; it is ready once its
console stops printing loading lines and starts accepting connections (look for `World initialized`
or the "listening" line). The first world-server start also applies the remaining Warband SQL
updates automatically — that is the intended delivery route for the merchant network and the other
shipped database content, so no manual import is needed.

Clean shutdown: close the **world server** console first, then the login server console, then stop
MySQL if you want it stopped. The world server saves online characters on shutdown.

> The zip also ships `scripts\Start-WowWarband.bat` and `Warband-Server.ps1`. Those scripts are for
> the project's development checkout (`bin\RelWithDebInfo`, a local MySQL under `var\`), not for the
> release layout. Ignore them and use the two commands above.

---

## 8. Create your account

In the **world server** console:

```
account create <name> <password>
```

For example `account create player1 changeme`. Optionally make it a GM so `.commands` work:

```
account set gmlevel player1 3 -1
```

(Account names are case-insensitive, max 16 characters.)

---

## 9. Client: realmlist, addons, first login

1. **Realmlist.** In the WoW client folder, `realmlist.wtf` must contain:

   ```
   set realmlist 127.0.0.1
   ```

   Create the file as plain text if it does not exist. Some clients also read
   `Data\enUS\realmlist.wtf`; set both if unsure.

2. **Addons.** Copy the three addon folders from the release into the client:

   ```bat
   set "CLIENT=C:\World of Warcraft"
   set "ADDONS=C:\WoWWarband\Interface\AddOns"
   xcopy /E /I /Y "%ADDONS%\Warband"          "%CLIENT%\Interface\AddOns\Warband"
   xcopy /E /I /Y "%ADDONS%\MultiBot"         "%CLIENT%\Interface\AddOns\MultiBot"
   xcopy /E /I /Y "%ADDONS%\PlayerbotManager" "%CLIENT%\Interface\AddOns\PlayerbotManager"
   ```

   Copy only these three subfolders into `Interface\AddOns` — never the whole `AddOns` tree.

3. **Launch the client**, log in with the account from step 8, pick the realm, and create a
   character. Every race/class combination is available.

4. In game:

   * `/warband` or `/ww` opens the Warband settings panel.
   * The Friends frame (`O`) has a **Party** tab: invite your companions there.
   * The Dungeon Finder is the party travel menu.

---

## 10. When something goes wrong

- **`dbimport.exe` stops with "The given source directory … does not exist".**
  Cause: `SourceDirectory` not set. Fix: set it (step 4.2) in `dbimport.conf` and both server confs.

- **"Didn't find any executable MySQL binary … correct the path in the *.conf ("MySQLExecutable")".**
  Cause: `mysql.exe` not found. Fix: set `MySQLExecutable` (step 4.3) or add MySQL's `bin` to `Path`.

- **"DatabasePool … NOT opened" / connection refused at server start.**
  Cause: MySQL not running, or wrong credentials. Fix: start the MySQL service, check the
  `DatabaseInfo` lines, retry.

- **World server exits while loading and mentions `dbc` or `maps`.**
  Cause: `data\` incomplete, or `DataDir` wrong. Fix: complete step 6 and check `DataDir` (4.4).

- **Login shows no realm.**
  Cause: `realmlist.wtf` wrong, or login/world server not running. Fix: `set realmlist 127.0.0.1`;
  confirm both consoles are up and past their "listening" line.

- **Login server exits with "No valid realms specified".**
  Cause: a world server was interrupted mid-load; the realm row is marked offline + version
  mismatch (flag 3). Fix:
  `UPDATE acore_auth.realmlist SET flag = 0 WHERE flag = 3;` then start the servers again.

- **Windows says "This app can't run…" or msvcp140.dll / vcruntime140.dll is missing.**
  Cause: no VC++ runtime. Fix: install the 2015-2022 x64 redistributable and retry.

- **Item tooltips show stale prices after an update.**
  Cause: the client's item cache. Fix: close the client and delete `Cache\WDB\itemcache.wdb`,
  `Cache\WDB\itemnamecache.wdb` and `Cache\WDB\itemtextcache.wdb`.

- **The client closes on launch with addon errors.**
  Cause: addons missing or in the wrong folder. Fix: redo step 9.2; `Interface\AddOns\` must
  contain `Warband`, `MultiBot` and `PlayerbotManager` with that exact spelling.

---

## 11. Updating an existing install later

When a newer release appears:

1. Stop both servers.
2. Replace the contents of `bin\` with the new release's `bin\`. Keep your `data\` folder — the
   format does not change.
3. Run `dbimport.exe` once from the new `bin\` to apply new SQL.
4. Copy the new addons over the old ones and clear the client item cache (step 10, last row).

The client never changes: it stays World of Warcraft 3.3.5a, build 12340.

---

## Appendix A — ports and files worth knowing

| Port | Service |
| ---- | ------- |
| 3306 | MySQL |
| 3724 | login server (`authserver`) |
| 8085 | world server (`worldserver`), also the port in `acore_auth.realmlist` |

| File | Role |
| ---- | ---- |
| `bin\configs\worldserver.conf` | world server settings: `DataDir`, database, Warband switches |
| `bin\configs\modules\mod_warband.conf` | every Warband server option |
| `bin\configs\authserver.conf` | login server settings: database, realm port |
| `bin\configs\dbimport.conf` | database importer: credentials, `SourceDirectory`, `MySQLExecutable` |
| `bin\DBImport.log`, `bin\Server.log`, `bin\Auth.log` | logs to read when a start fails |

## Appendix B — server folder after a full install

```
C:\WoWWarband\
    bin\              authserver.exe, worldserver.exe, dbimport.exe, extractors, DLLs
    bin\configs\      worldserver.conf, authserver.conf, dbimport.conf, modules\
    data\dbc\         extracted DBC files
    data\maps\        extracted terrain maps
    data\vmaps\       extracted collision/movement data
    data\mmaps\       generated navigation meshes
    Interface\AddOns\ Warband, MultiBot, PlayerbotManager
    scripts\          developer helpers (see the note in step 7)
```

## Appendix C — client

WoW 3.3.5a build 12340 is not part of the release and is not redistributable — use a client you
already own. Any 3.3.5a install works; the addons are for 3.3.5a (`TOC 30300`).

Building the server from source instead of using a release is covered in
[WowWarband-Setup.md](WowWarband-Setup.md).
