# Build & tests

WoW Warband builds require explicit user approval. Before configuring, building,
or rebuilding, explain why it is needed, identify the source/build scope and
whether Playerbots will be rebuilt, and estimate duration and material resource
cost. Wait for approval of that scope before starting. Full builds including
Playerbots are especially costly. Approval to change code does not approve a
build. See `doc/Warband-Implementation-Policy.md`.

Out-of-source build is required (in-source is blocked).

```bash
mkdir -p build && cd build
cmake .. -DCMAKE_INSTALL_PREFIX=$HOME/azeroth-server -DCMAKE_BUILD_TYPE=RelWithDebInfo \
  -DSCRIPTS=static -DMODULES=static
make -j$(nproc) && make install
```

C++20 required (`CMAKE_CXX_STANDARD 20`). Useful flags: `BUILD_TESTING=ON` (Google Test), `NOPCH=1` (disable precompiled headers). Full set in `conf/dist/config.cmake`. `compile_commands.json` is exported automatically.

Tests (Google Test, in `src/test/`): configure `-DBUILD_TESTING=ON`, then `ctest` or `./src/test/unit_tests` from the build dir.
