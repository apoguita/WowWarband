# WoWWarband with Docker: run the published server

This guide runs a WoWWarband server from the images published on GitHub Container Registry, on
Docker Desktop (Windows/macOS) or Docker Engine on Linux, without compiling anything. It covers
the prerequisites, the compose files, the first start, the account and the client.

It is the container twin of [WowWarband-Install.md](WowWarband-Install.md): that one installs the
Windows release zip, this one runs the servers in containers. Building from source instead is
[WowWarband-Setup.md](WowWarband-Setup.md).

---

## 1. What you are running

| Image | What it is |
| ----- | ---------- |
| `ghcr.io/apoguita/wowwarband-worldserver` | the world server, with every Warband module compiled in (`mod-warband`, `mod-playerbots`, …) |
| `ghcr.io/apoguita/wowwarband-authserver` | the login server |
| `ghcr.io/apoguita/wowwarband-db-import` | the database tool: creates the three core databases and applies every SQL update, Warband's pending updates included, so the supplier merchant network arrives with no import step |
| `ghcr.io/apoguita/wowwarband-client-data` | downloads the map data volume once (`dbc`, `maps`, `vmaps`, `mmaps`) |
| `ghcr.io/apoguita/wowwarband-tools` | the map extractors, for building the data from your own client |
| `ghcr.io/apoguita/wowwarband-dev-server` | a build server for development from source, started only with the `dev` profile |

Each image is published from a release tag (`v0.6.0` publishes `:0.6.0` and `:latest`) and the
images are built for `linux/amd64`. What is **not** in them is what is not redistributable or is
per-machine: the WoW client, the extracted map data (downloaded or generated, step 6), and the
databases (created on first start).

The containers also apply the project's configuration decisions for you: `data/configs/` is
written onto the installed configs by a one-shot `warband-config` service before the servers
start (step 5.3), the same values `Warband-Configs.ps1 -Action apply` writes on a Windows install.

---

## 2. Prerequisites

| Requirement | Details | Check |
| ----------- | ------- | ----- |
| Docker Desktop (Windows/macOS) or Docker Engine + Compose plugin (Linux) | Compose v2 (`docker compose`, not `docker-compose`). Windows/macOS needs WSL2 behind Docker Desktop. | `docker compose version` |
| ~15 GB free disk space | images + map data volume + four databases | `docker system df` |
| 8 GB RAM recommended | the world server with playerbots is the hungry one | |
| A WoW 3.3.5a client, build 12340 | yours; not shipped. Only needed for the client side (step 7) | `Data\enUS\` present |
| The three Warband client addons | `addons/Warband` in this checkout; `MultiBot` and `PlayerbotManager` ship in the release zip | step 7.2 |

Nothing else is installed on the host: no MySQL, no compiler, no map extractors.

---

## 3. Get the compose files

The stack is defined by two files at the repository root plus the tracked config deltas they
mount. A shallow clone is enough — the images are already built, so the module submodules are not
needed:

    git clone --depth 1 https://github.com/apoguita/WowWarband.git
    cd WowWarband

No Git? Download the repository zip from the same GitHub page and unpack it. The files that matter
are `docker-compose.yml`, `docker-compose.warband.yml`, `data/configs/` and `conf/dist/env.docker`.

---

## 4. Configure

Copy the template and fill in a value to your taste:

    copy conf\dist\env.docker .env      # PowerShell, Windows
    cp conf/dist/env.docker .env        # Linux / macOS

`conf/dist/env.docker` lists every variable. The ones that matter for this stack:

| Variable | Default | What it does |
| -------- | ------- | ------------ |
| `WARBAND_IMAGE_TAG` | `latest` | image tag. Pin a version (`0.6.0`) to stay on a release; `latest` follows the newest tag |
| `DOCKER_DB_ROOT_PASSWORD` | `password` | the MySQL root password inside the database container |
| `DOCKER_WORLD_EXTERNAL_PORT` | `8085` | the world server port on the host — the port in `realmlist` |
| `DOCKER_AUTH_EXTERNAL_PORT` | `3724` | the login server port on the host |
| `DOCKER_DB_EXTERNAL_PORT` | `3306` | the MySQL port on the host. **Change it if a local MySQL already uses 3306** |
| `DOCKER_VOL_DATA` | `ac-client-data` | where the map data lives: a named volume, or a folder path such as `./var/data` |
| `DOCKER_VOL_ETC` | `./env/dist/etc` | where the installed configs live on the host |

Leave `WARBAND_IMAGE_PREFIX` alone unless you publish the images to a different namespace.

---

## 5. Start it

### 5.1 Pull and bring the stack up

    docker compose -f docker-compose.yml -f docker-compose.warband.yml pull
    docker compose -f docker-compose.yml -f docker-compose.warband.yml up -d --no-build

`--no-build` matters: both files reference the same service names, and the base file also carries
`build:` sections, so without it Compose would start a multi-hour C++ build from the checkout
instead of using the published image.

If the pull fails with `unauthorized`, the package is still private: make it public under the
repository's **Packages** settings (package → Package settings → Change visibility), or log in
once with `docker login ghcr.io`.

### Or: build the images from this checkout

None of the above requires published images. They are a shortcut that saves the compile; the same
two files build the whole server from this checkout, with Docker doing the compiling:

    git submodule update --init --recursive modules
    docker compose -f docker-compose.yml -f docker-compose.warband.yml build
    docker compose -f docker-compose.yml -f docker-compose.warband.yml up -d --no-build

Use this when the registry has nothing yet, when you want your own changes in the server, or when
you have no GHCR access. The images keep their `ghcr.io/…` names but are built and stored locally;
nothing is downloaded. Budget fifteen minutes to an hour: it compiles core and all modules
including Playerbots, the same work [WowWarband-Setup.md](WowWarband-Setup.md) describes for a
native build. That clone step is also the only place the module submodules are needed.

What the first start does, in order:

1. `ac-database` (MySQL 8.4) comes up and reports healthy.
2. `ac-db-import` creates `acore_auth`, `acore_characters` and `acore_world`, loads `data/sql/base`,
   then applies the updates — Warband's supplier merchant network among them. A few minutes on
   the first run.
3. `warband-config` seeds `./env/dist/etc` from the image and writes the tracked `data/configs`
   values into it (step 5.3).
4. `ac-client-data-init` downloads the map data into the `ac-client-data` volume. Several GB, once;
   later starts skip it because the volume carries a `data-version` marker.
5. `ac-authserver` (3724) and `ac-worldserver` (8085) start and wait for the pieces above.
6. The **first world-server start creates `acore_playerbots`** and fills it from the playerbots SQL
   that ships inside the image — 71 MB of tables, so expect a couple of extra minutes once. Every
   later start only validates it. This is the one database the world server owns; the other three
   belong to `ac-db-import`.

### 5.2 Watch the logs

    docker compose -f docker-compose.yml -f docker-compose.warband.yml logs -f ac-db-import
    docker compose -f docker-compose.yml -f docker-compose.warband.yml logs -f ac-worldserver

The first world start also fills `acore_playerbots` from the module SQL inside the image (step 6
above); it is ready once the log passes `World initialized` and the world socket is listening.

### 5.3 What `warband-config` writes

It is the container form of `Warband-Configs.ps1 -Action apply`: only the keys named in
`data/configs/` are written, everything else in each config stays as shipped, and a key that is
missing is appended with a note. On this stack that means the Warband XP rate and the other module
defaults, `MinPetitionSigns = 0` so a bot-signed guild charter needs no signatures,
`MaxPrimaryTradeSkill = 11`, `EnablePlayerSettings = 1`, and the supplier price multipliers.

Two keys are deliberately **not** copied: `BindIP` (a container has to listen on `0.0.0.0` for the
published port to reach it) and the machine-specific `DataDir` / `*DatabaseInfo` credentials.

The patched files are on the host under `env/dist/etc/`, so they can be edited like any install.
`warband-config` is idempotent: it runs again on every `up` and re-applies the tracked values.

### 5.4 Stop and restart

    docker compose -f docker-compose.yml -f docker-compose.warband.yml stop
    docker compose -f docker-compose.yml -f docker-compose.warband.yml down

`down` keeps the database and map-data volumes; `down -v` deletes them, next start imports the
databases again. Close the world server before the login server if you want a clean character
save — `stop` does that in reverse dependency order.

---

## 6. Map data: download or extract

By default the map data is downloaded by `ac-client-data-init` from the `wowgaming/client-data`
release — no client needed on the host.

If you already have extracted data (from an earlier install, or generated with the extractors),
point the volume at the folder instead:

    # .env
    DOCKER_VOL_DATA=./var/data

The folder must contain `dbc/`, `maps/`, `vmaps/` and `mmaps/`. The world server mounts it
read-only.

To extract from your own client instead, use the `tools` profile — it mounts the client folder and
carries `map_extractor`, `vmap4_extractor`, `vmap4_assembler` and `mmaps_generator`:

    # .env
    DOCKER_AC_CLIENT_FOLDER=C:/World of Warcraft

    docker compose --profile tools -f docker-compose.yml -f docker-compose.warband.yml \
        run --rm ac-tools bash

Then run the four extractors inside that shell in the order given in
[WowWarband-Install.md](WowWarband-Install.md) step 6, writing into `/azerothcore/env/dist/data`.
That is the same half-hour-plus work as the Windows guide; the download is the easier path.

---

## 7. Client

### 7.1 Realmlist

The shipped `acore_auth.realmlist` row says `127.0.0.1` on port 8085, which is exactly the
published host port, so a client on the same machine needs nothing beyond:

    set realmlist 127.0.0.1

A client on another machine needs the host's address in the database — run this once in the
database container:

    docker exec -it ac-database mysql -uroot -p
    -- then, in the MySQL prompt:
    UPDATE acore_auth.realmlist SET address = '<host ip>' WHERE id = 1;

### 7.2 Addons

`addons/Warband` is in the checkout. `MultiBot` and `PlayerbotManager` are the module-owned addons:
they ship in the release zip (`Interface\AddOns\`), and a checkout can fetch them with
`git submodule update --init addons`. Copy the three folders into the client:

    set "CLIENT=C:\World of Warcraft"
    xcopy /E /I /Y "addons\Warband"          "%CLIENT%\Interface\AddOns\Warband"
    xcopy /E /I /Y "<release>\MultiBot"      "%CLIENT%\Interface\AddOns\MultiBot"
    xcopy /E /I /Y "<release>\PlayerbotManager" "%CLIENT%\Interface\AddOns\PlayerbotManager"

Copy only these three subfolders into `Interface\AddOns` — never the whole tree. Clear the client
item cache after an update the same way the Windows guide describes.

---

## 8. Create your account

Attach to the world server console:

    docker attach ac-worldserver

Then:

    account create <name> <password>
    account set gmlevel <name> 3 -1      # optional, for .commands

Detach with `Ctrl+P Ctrl+Q` (that keeps the server running); `Ctrl+C` stops the container. The
same console answers `.warband …` commands, so the console is also where the Warband switches and
supplier prices can be tuned.

---

## 9. Updating

    git pull
    docker compose -f docker-compose.yml -f docker-compose.warband.yml pull
    docker compose -f docker-compose.yml -f docker-compose.warband.yml up -d --pull always --no-build

A new image brings new `data/sql` with it; `ac-db-import` runs on every `up` and applies the
update files it has not applied yet. `data/configs` and `env/dist/etc` stay where they are.

Pinning a version is done in `.env` (`WARBAND_IMAGE_TAG=0.6.0`); `latest` is re-pointed by every
release tag.

---

## 10. When something goes wrong

- **`pull access denied` / `unauthorized`.** The GHCR package is private: make it public in the
  repository's Packages settings, or `docker login ghcr.io` with a token that can read packages.

- **`port is already allocated`.** A local MySQL (3306) or another server (3724/8085) is running.
  Set `DOCKER_DB_EXTERNAL_PORT` / `DOCKER_AUTH_EXTERNAL_PORT` / `DOCKER_WORLD_EXTERNAL_PORT` in
  `.env`, or stop the other process.

- **World server exits complaining about `dbc`, `maps` or `mmaps`.** The map data volume is empty
  or incomplete: `docker compose logs ac-client-data-init`, check `DOCKER_VOL_DATA`, and if you
  downloaded manually confirm all four folders are present.

- **World server exits with "DatabasePool … NOT opened".** MySQL is not healthy yet or the password
  changed: `docker compose logs ac-database`, and check `DOCKER_DB_ROOT_PASSWORD` in `.env`.

- **World server exits with `DBUpdater: The given source directory … does not exist`, or
  `Directory ".../modules/mod-playerbots/data/sql/playerbots/base" not exist`.** The image was
  built without the playerbots module SQL (an image from before this stack was finished, or from a
  branch without the `COPY` in `apps/docker/Dockerfile`). Pull a current image; the Warband
  world-server image carries that SQL so it can create `acore_playerbots` itself.

- **`warband-config` fails or wants a config file it cannot find.** Run it by hand and read its
  output: `docker compose -f docker-compose.yml -f docker-compose.warband.yml logs warband-config`.
  It needs `data/configs/` in the compose project directory.

- **Login shows no realm.** Confirm `ac-authserver` and `ac-worldserver` are up and listening
  (`docker compose ps`), and that `realmlist` holds the address your client uses (7.1).

- **Addons missing / client errors.** Only `Warband`, `MultiBot` and `PlayerbotManager` belong in
  `Interface\AddOns`, spelled exactly like that.

- **`docker compose up` starts compiling.** `--no-build` was omitted; Compose fell back to the
  `build:` sections of the base file. Stop it (`Ctrl+C`, `down`) and use the commands in 5.1.

---

## 11. Publishing the images

Publishing is **optional**. Everything in this guide works without it: a checkout builds the same
images itself (see the build route in 5.1). Publishing only means other people can `pull` instead
of compiling — which for a 15-minute compile is why the workflow exists.

The images are built by `.github/workflows/docker_publish.yml`:

- pushing a tag `v*` builds every component and publishes `<version>` and `latest`;
- running the workflow by hand (Actions → docker-publish → Run workflow) publishes `edge` from the
  branch it runs on.

One workflow run builds the shared C++/Playerbots stage once and the remaining components copy
their binaries out of it, so a release takes one full compile, not six. Forks publish under their
own owner (`ghcr.io/<owner>/wowwarband-*`) with the repository's own `GITHUB_TOKEN` — no secret
has to be configured.

## Appendix — ports and volumes

| Port | Service |
| ---- | ------- |
| `DOCKER_DB_EXTERNAL_PORT` (3306) | MySQL — not needed by players, useful for Keira3 |
| `DOCKER_AUTH_EXTERNAL_PORT` (3724) | login server |
| `DOCKER_WORLD_EXTERNAL_PORT` (8085) | world server, and the port in `acore_auth.realmlist` |
| `DOCKER_SOAP_EXTERNAL_PORT` (7878) | SOAP, only if you enable it in `worldserver.conf` |

| Volume / path | Contents |
| ------------- | -------- |
| `ac-database` | MySQL data directory |
| `ac-client-data` (or `DOCKER_VOL_DATA`) | `dbc/`, `maps/`, `vmaps/`, `mmaps/`, plus the `data-version` marker |
| `./env/dist/etc` (`DOCKER_VOL_ETC`) | the installed configs the servers read, patched by `warband-config` |
| `./env/dist/logs` (`DOCKER_VOL_LOGS`) | server logs, including `Server.log` and `Auth.log` |
