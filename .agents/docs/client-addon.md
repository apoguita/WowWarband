# Client addon (`addons/`)

Anything under `addons/`: the project's own addon in `addons/Warband/`, and the third-party client
addons the client ships with.

## An addon edit is not live until it is deployed

- The source of truth is `addons/Warband/`. The client does not read it: WoW loads its own copy from
  `var/client/<client folder>/Interface/AddOns/Warband/`.
- Deploy with `.\Deploy-WarbandAddon.ps1` (it copies and then verifies every file hash), and then
  **restart the WoW client**. A `/reload` re-runs the files the client already loaded and will not
  pick up a changed one — this is stated in the script header and it is the usual way a finished
  change is reported as "not applied".
- An addon-only change needs **no** server build, no CMake, no worldserver restart. Do not ask for a
  build for one, and do not take the rebuild route to move data that the client can read itself.
- Never diagnose through the repo copy alone. Before believing a bug report about an addon change,
  compare the hash of the repo file with the deployed one; a difference means the running code is the
  client's, not the one just edited.

## Draw-a-panel-over-a-Blizzard-window rules

These cost a wrong diagnosis once; both are structural, not cosmetic.

- **A full-size child frame eats every mouse-down**, including the click the window's own drag needs.
  BlizzMove moves Blizzard windows by putting the drag script on the frame itself
  (`SetMoveHandler(LFDParentFrame)`), so anything drawn over that frame silently takes the window's
  movability away. Whoever overlays a window owns its drag: `RegisterForDrag` on the overlay,
  `parent:StartMoving()` / `StopMovingOrSizing()`, and save the position (`Layout.lua` keeps them in
  `WarbandDB.layout`). Never rely on the frame underneath receiving the click.
- **Raise the window's own buttons above the overlay.** Blizzard's close button is a direct child of
  the frame; a full-size panel covers it unless its frame level is raised.

## Lua behaviour worth remembering

- Files are loaded independently, but a runtime error stops the rest of *that* file: every function
  defined after the error is nil for the rest of the session. Guard entry points (`if not built then
  return end`) instead of assuming a half-built panel is harmless.
- The client's 3.3.5 dungeon data answers `0` for fields it does not carry (for example a finder
  entry's recommended level), and `0` is truthy in Lua. A `tonumber(x) or fallback` keeps the 0 and
  produces a coherent-looking wrong answer; test for a *positive* number instead.
