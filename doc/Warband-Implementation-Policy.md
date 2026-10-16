# WoW Warband implementation policy

**Status:** active project policy  
**Last updated:** 16 October 2026

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

For each proposed feature, record whether it is research, selected dependency,
Warband-owned implementation, or implemented and verified. Keep those states
distinct in the README, design record, and component assessments. Do not call a
feature active because its source is present or because a build succeeded;
report database setup, configuration, runtime loading, and gameplay verification
separately where they apply.
