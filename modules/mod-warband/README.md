# mod-warband

The in-house server module for WoW Warband. Everything Warband-specific that
needs the server lives here: today the XP multiplier, follower catch-up
experience, follower gathering and binding-free items. The client panel in
`addons/Warband` drives the runtime settings through this module's `.warband`
chat commands.

The directory used to be called `mod-warband-unbound-loot`, after the first
feature it happened to carry. Binding-free loot is one feature of the Warband
module, not its identity, and the name now says so.

## Feature status

| Feature | State | Source |
| --- | --- | --- |
| XP multiplier | Live and verified in game | `WarbandSettings.cpp`, `WarbandCommands.cpp` |
| Follower catch-up XP | Live and verified in game | `WarbandSettings.cpp`, `WarbandCommands.cpp` |
| Binding-free items | Compiled in; behaviour not verified in game | `WarbandUnboundLoot.cpp` |
| Follower gathering | On-demand apply verified; automatic sync not yet verified | `WarbandGathering.cpp` |

Keeping the two kinds of bot apart is what `WarbandPlayerRoles.h` is for:
`WarbandFollowerMaster()` returns a leader only for a bot piloted by a real
player, so the XP, catch-up and gathering code never mistakes the world's random
bots for Warband followers.

There is **no in-house core patch**. Binding-free items are implemented entirely
in this module: nothing under `src/` was changed for them, so the module alone is
the whole mechanism.

## Entry point and build

`src/mod_warband.cpp` exposes `Addmod_warbandScripts()`. The loader generates
that name from the directory name (`modules/CMakeLists.txt` builds
`Add<directory, with dashes as underscores>Scripts()`), so renaming the directory
requires a CMake configure followed by a build, not just a rebuild.

Build approval is required before any configure or build, as described in
`doc/Warband-Implementation-Policy.md`. Everything else here is read and changed
at runtime, so tuning the features never needs a rebuild.

## XP multiplier

`Warband.XP.Rate` is a server-wide multiplier applied to every experience gain -
kills, quests, exploration and battlegrounds - for every character, followers
included. It must be a whole number from 1 to 10 and defaults to 3.

    .warband xp                 read the live multiplier, replies WARBAND_XP=<rate>
    .warband xp set <1-10>      apply a new rate immediately, replies the same way

Both commands are available at player permission level and do not need GM access.
Changes are runtime-only: a worldserver restart or `.reload config` restores the
value from the configuration file.

## Follower catch-up XP

A follower that is behind its leader earns extra experience, so a newly recruited
companion becomes useful without replaying the leader's history. The curve is
deliberately simple:

    catch-up multiplier = 1 + (Warband.CatchUp.PerLevel * levels behind)

A floor is applied afterwards and an optional cap last. The result multiplies the
already-multiplied experience, so at the shipped defaults a follower one level
behind gains 10% extra and one twenty levels behind gains 200% extra; at
`Warband.XP.Rate = 3` those amounts become x3.30 and x9.00.

It applies only to a bot piloted for a real player. The leader comes from
`PlayerbotAI::GetMaster()`, and a bot whose master has a headless session is left
alone, so the random bots that populate the world are never affected. Because
this is a Warband feature rather than a Playerbots one, Playerbots' own
`Playerbots.RandomBotXPRate` is untouched.

Both multipliers are applied in the same hook, `OnPlayerGiveXP`, which the core
calls before the amount is granted.

Configuration, all in `conf/mod_warband.conf.dist`:

| Option | Default | Meaning |
| --- | --- | --- |
| `Warband.XP.Rate` | 3 | Server-wide experience multiplier, whole numbers 1 to 10 |
| `Warband.CatchUp.Enabled` | 1 | Turn the catch-up bonus on or off |
| `Warband.CatchUp.PerLevel` | 0.10 | Extra experience per level of difference, 0 to 10 |
| `Warband.CatchUp.MinMultiplier` | 1.0 | Lowest multiplier while behind, 1 to 100 |
| `Warband.CatchUp.MaxMultiplier` | 0 | Upper limit, 0 for uncapped |
| `Warband.CatchUp.Debug` | 0 | Log each applied multiplier, at most once a second |

Out-of-range values are rejected at startup and on reload with an error log line,
and the default is used instead.

The values can be changed without a rebuild:

    .warband catchup                 read the current settings
    .warband catchup step <0-10>     extra experience per level behind
    .warband catchup floor <1-100>   lowest multiplier while behind
    .warband catchup cap <0-100>     highest multiplier, 0 for uncapped
    .warband catchup on | off        enable or disable

The reply is a single machine-readable line,
`WARBAND_CATCHUP=enabled=1;step=0.10;floor=1.00;cap=0.00;applied=0`, which the
addon reads to show live state on the XP Options tab. `applied` counts how many
times the bonus has been granted since the worldserver started, which makes the
feature verifiable without reading logs. At startup the worldserver logs the
active values, for example:

    Warband XP multiplier set to 3x
    Warband catch-up enabled: +0.1 per level behind, floor 1, cap uncapped

## Binding-free items

`WarbandUnboundLoot.cpp` clears the soulbound flag so that binding stops being a
barrier to moving equipment around the Warband. It clears
`ITEM_FIELD_FLAG_SOULBOUND` for:

- stored items at login: equipped slots, bags, bank and bank bags, keyring, and
  currency tokens;
- items arriving through the normal paths: stored in the inventory (loot,
  creation, quest rewards, rolls), moved into the inventory, taken from mail, or
  equipped.

Quest-bond items (`BIND_QUEST_ITEM`, `BIND_QUEST_ITEM1`) are deliberately left
alone, since clearing those would break the quests relying on them.

The core still sets the flag in the ordinary way, so the module clears it after
the fact rather than preventing it, and only on the paths listed above. The addon
lists this feature without runtime controls: there is no enable/disable command
yet, and the in-game behaviour still needs a focused verification pass.

## Follower gathering

The leader keeps the crafting professions; followers only need to gather for the
party. When the mirror is on, every follower in the party receives the leader's
Herbalism, Mining and Skinning skill values, so it can work the same nodes and
skin the same corpses. Playerbots already harvests whenever a bot has the skill -
`LootAction.cpp` casts Mining, Herb Gathering and Skinning whenever
`PlayerbotAI::HasSkill()` says so, and a node's lock is checked against the skill
value - so the missing piece is exactly the skill values.

Only the three gathering skills are mirrored, and only those the leader actually
has: a follower never loses a skill because the leader lacks it. The mirror is a
**floor, never a ceiling** - it only ever raises a follower, so a party member
that was trained further, or that was the character the player logged in as in an
earlier session, keeps its own progress. Whoever is being played pushes their
values out to the rest; nobody is dragged back down for having been the follower
while someone else was the leader.

Recipes and
crafting professions are deliberately not copied. The leader is the crafter, and
copying every recipe to every follower would bloat their spell maps and update
packets for no benefit; a gathering profession has no recipes anyway. The rank
spells the leader knows are copied with the skill, because those are what the
client uses to display the profession tier and what the bot casts on a node.

Writes only happen to a follower standing on the leader's map, which is also the
map thread, so the module never touches a player another thread owns. The mirror
runs on four occasions:

| Occasion | Hook |
| --- | --- |
| Leader logs in | `PlayerScript::OnPlayerLogin` |
| A follower joins the group | `GroupScript::OnAddMember` |
| A gathering skill gains a point | `PlayerScript::OnPlayerUpdateSkill` |
| A skill is written wholesale | `PlayerScript::OnPlayerSetSkill` |

The join case is the trigger that matters most, since followers normally join
after the leader is already in the world. The last two are what keeps the party in
step mid game instead of only at recruitment: working a node or a corpse raises
the leader's skill a point at a time, and a trained rank, `.setskill` or an
unlearned profession writes it wholesale. Both run on the map thread of the
player whose skill changed, which is the same rule the writes already follow.

The two paths are deliberately not the same work: a plain gain can never teach a
new rank spell, so that path copies values only, and the spell copy stays on the
SetSkill path. `OnPlayerSetSkill` is also how the mirror writes to a follower, so
that hook ignores events coming from a follower - otherwise a mirror would trigger
another mirror.

Because the hooks fire for every skill in the game, both filter on the three
gathering skill ids before doing anything else. A follower that gains a point on
its own keeps that point: its own progress is never undone, and it is only raised
further if it is still behind its leader.

    .warband gather              apply the mirror now and report the result
    .warband gather status       report the state without applying it
    .warband gather on | off     enable or disable the mirror
    .warband gather auto on|off  apply automatically on login, on join and on skill change

The reply is a single machine-readable line:

    WARBAND_GATHER=enabled=1;automatic=1;herbalism=450;mining=450;skinning=0;updated=2;applied=7

`herbalism`, `mining` and `skinning` are the leader's own values, which are what
followers receive. `updated` counts the followers changed by that application and
`applied` counts follower writes since the worldserver started, so the feature is
verifiable in game without reading logs. `applied` grows while you play, by
whatever the automatic paths needed, which is the quickest way to see the mid-game
sync working.

| Option | Default | Meaning |
| --- | --- | --- |
| `Warband.Gather.Enabled` | 1 | Turn the mirror on or off; `.warband gather` still applies on demand |
| `Warband.Gather.Automatic` | 1 | Apply on leader login, on follower join and on every gathering skill change |

Because the skills are written to the follower's own character data, they persist
after the feature is disabled. Clearing them again is a deliberate act, not a side
effect of turning the mirror off.

The GM side of testing this - giving the leader a profession, proving a follower
received it, and checking that nobody is ever lowered - is written up in
`.agents/plans/warband-gathering/warband-gathering.TESTING.md`.

