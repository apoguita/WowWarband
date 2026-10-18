# WoW Warband implementation policy

**Status:** active project policy  
**Last updated:** 16 October 2026

## Implementation default: in-house

**Warband implements every feature itself. A third-party module or addon is used only when a
recorded decision says so, naming the component and why Warband's own build does not supply
the behaviour.** This is the default, not a preference to be re-argued per feature:

- Nothing in this repository is a dependency by default. A link is a **citation** of research,
  never an install, and never a build input.
- **No candidate third-party source is staged in this tree, and none ever was.** `modules/`
  holds the runtime baseline (Playerbots, ALE, MultiBot Bridge, progression) and the
  project-owned `mod-warband`. The only upstream copies kept locally are read-only research
  clones under `.agents/reference/`, which nothing builds, configures, or loads.
- Any wording in the research documents that says a module was "staged", "pinned in this
  checkout", or "present as a submodule" is retired. Those statements were stale and are
  corrected wherever they appear.
- The research documents keep the *findings* — how a behaviour works, which hook it needs,
  which pitfalls were already hit — because that is what makes the in-house build cheaper.
  Reading upstream source is exactly how a Warband feature gets specified.

**Approved dependencies, in full.** These are recorded here so an exception can never be mistaken
for drift:

| Component | What it supplies | Why not in-house | Decided |
|---|---|---|---|
| `mod-ah-bot-plus` | The auction-house market: it lists items in all three houses and buys what players list | Writing a working auction market is a project of its own, and the requirement is movement on the house, not an economy Warband needs to own | 16 October 2026 |
| `mod-autobalance` | Instance difficulty scaling: creature health, mana and damage follow the group, so five members can fight a forty-man raid, and a dungeon scales up once the party outlevels it | Encounter difficulty maths is tuned against player count and carries its own curves; reimplementing it would be a project | 16 October 2026 |
| `mod-item-level-scaling` | Loot scaling: the same items with their stats moved to the party's level, and never downward | Item stat generation and publishing synthetic item templates is machinery of its own | 16 October 2026 |

Warband still owns the control surfaces: the `.warband ah` command and the panel's Auction house
page for the market, and the panel's Instances page for keeping instance creatures dead.

## Implementation model

WoW Warband owns the implementation of its intended player experience. A
third-party server module or client addon is not a general-purpose API that
automatically supplies a Warband feature. It is a separate software component
with a specific feature set, compatibility limits, setup requirements, and
possible database or runtime side effects.

For each feature, decide what the player should be able to do, then implement
the needed behavior in the appropriate Warband-owned layer:

- **Server behavior** belongs in a WoW Warband AzerothCore module (and in core
  changes only when a module cannot provide the required hook or behavior).
- **Player-facing client controls or display** belong in the WoW Warband client
  addon/plugin when the feature needs a custom interface or client interaction.
- Some features need both layers; server authority remains responsible for
  validating and applying gameplay actions.
- Existing project components can remain dependencies where they provide a
  deliberately selected, verified capability. They do not define the Warband
  product requirements.

The existing research documents are retained as reference material. Their
source reviews, feature comparisons, compatibility findings, and candidate
evaluations can inform design and implementation. A candidate's presence in a
shortlist, catalogue, submodule, or addon folder does not mean it is approved
for installation, activation, or use as a product dependency. Reuse a specific
component only after confirming that it supplies the exact needed behavior and
fits the player experience; otherwise use the research as a technical
reference when implementing the Warband-owned feature.

## Build approval and cost

Building or rebuilding this project can consume substantial time and machine
resources. A full rebuild that includes Playerbots is especially costly. Do not
start a configure, build, or rebuild as an assumed validation step.

Before any build operation, prepare a short estimate for the user that states:

1. why a build is needed and which source changes it must include;
2. whether it is a targeted module build or a full/core build, including whether
   Playerbots will be rebuilt;
3. the expected duration and other material resource cost, with uncertainty
   stated when the estimate is rough; and
4. the proposed approval point before the operation begins.

Wait for the user's explicit approval of that proposed build before running it.
Approval for code or documentation changes does not by itself approve a build.
If a new change materially expands the build scope or cost, provide an updated
estimate and obtain approval for that scope before proceeding.

## Decision record

For each proposed feature, record whether it is research, a Warband-owned
implementation, an approved dependency (the exception, with its reason), or
implemented and verified. Keep those states distinct in the README, design
record, and component assessments. Do not call a feature active because a
research copy exists or because a build succeeded; report database setup,
configuration, runtime loading, and gameplay verification separately where they
apply.

The only states a third-party component may carry in these documents are:
**reference only** (read for research; nothing in the build), **not taken up**
(candidate, no decision), and **approved dependency** (a recorded decision with
its reason). "Staged", "pinned" and "in modules/" describe nothing that exists
here and must not be used.
