# Playerbots incremental build validation

Validated on 16 October 2026 in the existing Windows build tree. The user
authorized the initial expensive compile and the follow-up incremental tests.

## Change and scope

Static Playerbots sources now compile in the `warband-playerbots` object target,
which feeds the existing `modules` archive. Playerbots still registers through
the static loader. Its compiler include paths exclude unrelated module trees.
The launcher reuses the existing cache, with `--configure` as a separate action.

The existing generator was Visual Studio 17 2022, using RelWithDebInfo, static
scripts/modules, and `--parallel 4`. The same worldserver build command was
used for the first compile, each source-change experiment, and restoration:

```text
cmake --build build --config RelWithDebInfo --target worldserver --parallel 4
```

MSBuild binary logging was also enabled. Timings cover the command's wall time,
including dependency checks and linking. Object hashing was performed outside
the timed command. This was an initial compile of the new Playerbots target,
not a clean rebuild of every dependency or a before/after benchmark of the old
build implementation.

## Results

| Operation | Elapsed | Result |
| --- | ---: | --- |
| Initial configuration | 2.62 s | Passed |
| First server build after target split | 588.94 s (9m 49s) | All 662 Playerbots sources compiled; server linked |
| Minor backend implementation change | 12.18 s | Server linked; 662/662 Playerbots objects unchanged |
| Restore backend implementation | 8.56 s | Passed; 662/662 Playerbots objects unchanged |
| Configure with an added module | 2.20 s | Passed |
| Build with the added module | 67.46 s | Passed; 662/662 Playerbots objects unchanged |
| Configure after removing the module | 2.19 s | Passed |
| Build after removing the module | 67.45 s | Passed; 662/662 Playerbots objects unchanged |
| Launcher configuration-only mode | 2.21 s | Passed without server compilation/install |
| Launcher build/install with no source changes | 3.02 s | Passed |
| Final build/install with corrected Git revision metadata | 7.96 s | Passed |

The backend experiment changed one log-message string in
`src/server/game/Motd/MotdMgr.cpp`. The log confirms that this source recompiled
and the server relinked. Its original bytes were restored afterward.

The second experiment added `modules/mod-warband-build-probe/src/Probe.cpp`,
containing an empty script-registration function, then reconfigured and built.
This deliberately changed the module source/include lists. The generated loader
and remaining combined module target rebuilt, but Playerbots did not. The probe
files and their temporary CMake cache entries were removed afterward.

For every experiment and restoration, all 662 Playerbots object files were
compared with the post-initial-build baseline by name, size, UTC modification
timestamp, and SHA-256 hash. Every comparison had zero changed records. The
final audit repeats that check after the launcher runs.

## Final state and evidence

- Temporary backend source changes were restored byte-for-byte.
- The probe module and its CMake cache entries are absent.
- The final installed `worldserver.exe` matches the restored build output by hash.
- C++ style checks and `git diff --check` passed.
- No game server was started and no gameplay test was performed.
- Early build logs contain Git ownership diagnostics from the restricted
  execution account. The final configure/build used a process-scoped trust entry
  for this exact checkout, restoring Git revision metadata without modifying
  global Git configuration. Boost also emitted its Windows-version fallback
  notice. These did not cause a compiler or linker failure.

Local logs, timing JSON, object manifests, binary logs, the test driver, and the
restored source backup are retained in the ignored directory
`var/build-validation/playerbots-isolation/`. The initial binary log is
`build/var-first-build.binlog`. The main audit is
`var/build-validation/playerbots-isolation/final-audit.json`.

## What this establishes

Small backend implementation edits and addition of an unrelated module can now
build successfully while reusing all Playerbots objects. This does not freeze
Playerbots binaries: edits to its own source, included shared headers, compiler
flags, toolchain, or configuration must still trigger necessary compilation.
Future builds remain subject to the project's user-approval policy.
