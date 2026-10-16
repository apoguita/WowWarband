# Build & tests

WoW Warband builds require explicit user approval. Before configuring, building,
or rebuilding, explain why it is needed, identify the source/build scope and
whether Playerbots will be rebuilt, and estimate duration and material resource
cost. Wait for approval of that scope before starting. Full builds including
Playerbots are especially costly. Approval to change code does not approve a
build. See `doc/Warband-Implementation-Policy.md`.

## WoW Warband Windows incremental builds

- Inspect the existing cache and compiler tracking logs before changing build
  settings. Do not switch static/dynamic linkage, clean the tree, touch source
  timestamps, or disable dependency checks to avoid Playerbots compilation.
- `Build-WowWarband.bat` builds/installs incrementally with the existing cache.
  `--configure` configures only and preserves existing cache choices. Both still
  require the scope/cost approval above. CMake may regenerate during a build
  after build-definition changes; adding globbed source files needs explicit
  configuration.
- Static Playerbots sources compile in the `warband-playerbots` object target
  and are embedded in `modules`. Keep unrelated module include directories and
  feature-specific compiler options out of this target. It must retain real
  dependencies on core headers and compiler settings.
- The target split requires one initial Playerbots compile after regeneration.
  That migration completed in this build tree on 16 October 2026: 588.94 seconds.
  A backend implementation edit took 12.18 seconds, with all 662 Playerbots
  objects unchanged; adding a temporary module also reused every object.
  Shared-header changes can still rebuild affected Playerbots sources. Budget
  and approve any future full Playerbots compile separately. See
  `doc/Playerbots-Build-Validation.md` for scope and evidence.

## Generic upstream build reference

Out-of-source build is required (in-source is blocked).

```bash
mkdir -p build && cd build
cmake .. -DCMAKE_INSTALL_PREFIX=$HOME/azeroth-server -DCMAKE_BUILD_TYPE=RelWithDebInfo \
  -DSCRIPTS=static -DMODULES=static
make -j$(nproc) && make install
```

C++20 required (`CMAKE_CXX_STANDARD 20`). Useful flags: `BUILD_TESTING=ON` (Google Test), `NOPCH=1` (disable precompiled headers). Full set in `conf/dist/config.cmake`. `compile_commands.json` is exported automatically.

Tests (Google Test, in `src/test/`): configure `-DBUILD_TESTING=ON`, then `ctest` or `./src/test/unit_tests` from the build dir.
