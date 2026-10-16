# WoW Warband: Product Direction

**Status:** active design direction  
**Last updated:** 15 October 2026

This document records the intended player experience for WoW Warband. It is not
an implementation plan. Existing Playerbots, MultiBot, Bridge, and progression
module capabilities are technical inputs, not automatic product requirements.

## Tested Runtime Baseline

The server and client installation has already been tested successfully. The
player can log in, create a character, play, and use companions that follow and
fight. This baseline is not an installation-work item and should not be restarted
as part of this design work.

## Confirmed Design Decisions

WoW Warband is a **single-player WoW experience** with a party of AltBots that
act like Guild Wars heroes: self-sufficient combat companions and an extension
of the player.

### Companion Model Under Exploration

The current leading model is **follower players**: real Playerbot characters
presented as Guild Wars 1-style heroes. They accompany the leader through the
campaign, follow and fight alongside them, and contribute a chosen combat role
to the active party. This is a working direction, not a final decision. It
avoids making them independent adventurers with player-managed lives, quest
journeys, professions, or routine inventories.

The player may equip a companion and shape that companion's equipment, talents,
build, and appearance. A companion has inventory because the underlying
Playerbot character needs item storage and equipment slots, but general
inventory management is not part of the player-facing experience.

Likewise, the working model has no **player-facing quest log** or independent
questing workflow. Internal Playerbot quest state may exist when it is needed to
keep a follower aligned with the leader's campaign, access gates, rewards, or
BoP eligibility. The design aim is that hidden technical state should not make
the player accept, track, abandon, or turn in routine quests for each follower.

The player shapes each companion's combat role through:

- equipment;
- talents and builds; and
- appearance.

Companion-managed belongings are limited to equipment. Routine management of
general inventories, professions, and other independent character systems is
outside the intended experience. Existing bot-tool support for those systems
does not turn them into product requirements.

## Preferred Player Behavior

The following expresses the desired experience. It is intentionally separate
from confirmed technical behavior and may need refinement after investigation.

### Party Growth

Companions should join gradually rather than all at once. The intended milestone
is a complete party of five AltBots unlocked by level 15.

Open design detail: the document does not yet choose the precise unlock cadence,
eligibility rule, or whether every unlock is fixed, role-selected, or otherwise
earned.

### Questing

The preferred quest flow is:

1. the leader accepts, tracks, fulfils, and turns in campaign quests;
2. followers receive any internal eligible quest state needed to remain aligned
   with the leader, without a separate player-facing quest workflow;
3. the leader is the only member who must fulfil quest objectives; and
4. after the leader completes a quest, an eligible follower can receive the
   appropriate completion and reward even if its internal counters were not
   completed.

Independent companion quest logs are not desired as a player-management system.
Internal quest state remains an implementation question only where it is needed
to enable this flow, catch-up, Bind on Pickup handling, or another confirmed
design goal.

### Current Quest-Progression Hypothesis

The leader owns the campaign pace. A follower should be able to join after the
campaign has begun, become aligned enough to participate in the leader's current
story, and remain aligned as the leader advances. The player should not have to
replay the campaign separately for each follower.

The current candidate behavior is:

1. on recruitment, synchronize the follower with the leader's necessary
   campaign progress and level; and
2. during play, give the follower any eligible internal quest state it needs,
   but let only the leader perform objectives and drive turn-ins; then
3. complete the follower's eligible quest and reward path when the leader turns
   in, even if the follower's own objective counters are incomplete.

This is a desired behavior, not a claim that it works universally today.
Playerbots' existing quest synchronization is promising evidence for the
turn-in portion. Recruitment catch-up, prerequisite handling, level alignment,
quest choices, rewards, and exceptions still need separate design and runtime
validation.

### Shared Campaign Progress

Shared Warband campaign progress is the preferred direction for preventing
late-added companions from falling behind. It is not implemented or technically
confirmed.

"Shared campaign progress" could mean several different things:

- **Campaign entitlement ledger:** a Warband-level record of completed campaign
  milestones. A later companion satisfies relevant access gates, without copying
  every quest state or past reward.
- **Shared completion state:** companions are treated as complete for selected
  leader-completed quests, allowing their own turn-in flow where needed.
- **Join-time catch-up:** a companion receives specific progress only when it
  joins the Warband, rather than continuously sharing progress.
- **Gate-only sharing:** account- or Warband-wide attunements and campaign gates
  are shared while ordinary quests remain leader-only.

These alternatives have different implications for quest choices, repeatable
content, reputation, experience, rewards, and the amount of hidden companion
state. None has been selected.

## Bind on Pickup: Why Quest Eligibility May Matter

Bind on Pickup (BoP) is the main reason a companion may need quest eligibility
or completion state. It should be explored before deciding whether companion
quest state is needed at all. Removing BoP is not a decision and is not assumed.

Practical directions to evaluate:

- **Each eligible companion receives its own reward.** This preserves ordinary
  BoP ownership and supports equipment growth, but requires the companion to
  have enough quest state to claim that reward.
- **The leader receives the reward and routes it to a companion.** This keeps
  leader-centric questing, but ordinary BoP restrictions can prevent transfer
  and would require a carefully designed exception or reward-routing system.
- **A Warband/account eligibility layer handles selected rewards.** This could
  avoid per-companion quest administration, but changes binding semantics and
  needs strict ownership, duplication, and exploit rules.
- **Content-specific reward treatment.** Selected rewards could follow special
  rules while ordinary BoP remains intact. This narrows scope, but creates a
  less uniform experience and requires a content policy.

### Existing BoP Trade Window: Test Before Broadening the Rules

BoP does **not** by itself require companions to be account characters or to
share quest logs. Those are separate design choices.

The current core source contains a group-loot trade path for certain items. With
`Item.SetItemTradeable` enabled, an eligible, non-stackable Bind on Pickup or
quest-bound item can preserve a two-hour trade window for its allowed looters.
The same path is used when an item is sent by mail after a group roll. This is
source evidence only: the effective local configuration and the AltBot trading
experience have not been tested.

The test-first question is therefore whether the specific companion-gear cases
already fit this normal group-loot mechanism. A focused future test should cover
the actual loot method, eligible group members, direct-loot and roll/mail paths,
the recipient's bag space, and whether an AltBot can receive the trade during
the window. It should not change BoP rules merely because the general mechanic
exists.

Removing BoP entirely remains an option, but is not selected. It would alter
loot rules throughout the world, rather than solving only a Warband equipment
case.

### Binding-Free Equipment: Alternative Under Exploration

For a single-player Warband, removing ordinary item-binding friction is a
plausible alternative to per-item BoP exceptions. The desired benefit is that
usable equipment can move to the appropriate follower without requiring account
character status, synchronized quest logs, or a special trade-window case.

This would be a **server-side rule change**, not a client addon. The researched
catalogue does not currently provide a maintained, comprehensive module that
disables all AzerothCore binding behavior.

An in-repository technical prototype now exists at
`modules/mod-warband-unbound-loot`. It clears the normal instance-level
soulbound flag for existing and newly received non-quest items, including the
ordinary BoP and BoE equipment paths. It is deliberately narrower than
"disable all binding": it does not modify quest-template items, enchant-caused
binding, or the core's direct Bind-on-use path. It is unbuilt and untested in
the running server, and its existence does not select binding-free equipment as
the product rule.

"Disable all binding" needs further definition before it is a decision:

- **BoP and BoE equipment:** the prototype is a feasible, reversible starting
  point for these normal equipment rules. Bind-on-use requires a separate core
  integration decision because the server applies it outside the available
  generic item hooks.
- **Quest items:** these are not merely equipment restrictions; they interact
  with quest ownership, completion, unique limits, and inventory checks. Keeping
  their normal safeguards while hiding their logistics may be safer.
- **Existing soulbound items and non-binding restrictions:** an implementation
  must decide how it treats items already bound, Bind on Account, unique-item
  limits, keys, no-trade flags, mail, Auction House eligibility, and rewards.

The chief tradeoff is progression: fully transferable gear removes a major
source of friction, but makes duplicate drops, Auction House purchases, and
over-level equipment much easier to route to any party role. That may be desired
for this experience, but it should be chosen alongside item-level and campaign
availability rules rather than assumed to be harmless.

## Technical Findings to Validate

Source inspection of the pinned `mod-playerbots` checkout finds an existing
quest-synchronization path for player-led bots, including AltBots. This is useful
evidence, not runtime confirmation for this installation.

### What the Source Supports

- `Playerbots.SyncQuestWithPlayer` is enabled by default in the distributed
  configuration. Its documented behavior is that bots complete quests when the
  player hands them in and do not loot quest items.
- The quest-giver action checks whether the leader has completed a quest while a
  bot has it incomplete. When that condition holds, it completes the bot quest
  and then follows the normal reward path.
- The completion helper fills required item and creature/game-object objectives,
  applies required reputation or money conditions, and marks the quest complete.
  This is a completion-at-turn-in mechanism, not evidence of live shared
  objective counters during play.
- Playerbot registers the leader's quest-accept packet and includes native
  quest-sharing acceptance handling. A companion can therefore have quest state,
  subject to the normal acceptance rules.

### Limitations and Questions

- A companion must be eligible to accept the quest and have quest-log capacity.
  Prerequisites, level, class, race, reputation, group-distance, party-sharing,
  and quest-specific rules can still block it.
- The observed path depends on the synchronization setting and companion quest
  state. The effective setting in this installation has not been checked or
  changed.
- The source evidence does not establish a full Warband-level campaign model,
  automatic acceptance for every quest, or a player-facing workflow that hides
  companion quest administration.
- Quest rewards can include choices, inventory space requirements, money,
  reputation, experience, unique-item limits, and BoP items. Each needs defined
  behavior before a reward model is chosen.
- Current AltBot reward behavior can auto-select rewards according to the
  Playerbots setting. That existing behavior is not yet a suitable product
  decision for role-directed companion equipment.

### Feasibility Assessment

The desired "leader completes objectives; companion completes and turns in"
behavior has a plausible existing foundation in Playerbots. It is not yet
confirmed as a reliable AltBot experience for every quest type, nor does it
solve late-join catch-up or BoP ownership by itself. Validation should be a
targeted design-and-runtime audit before any server, configuration, or addon
change is proposed.

## Alternatives and Tradeoffs Still Open

### Quest State

- **Use the existing per-companion synchronized quest state.** Lowest initial
  implementation scope and preserves normal quest rewards, but retains hidden
  companion logs and can expose edge cases from individual eligibility.
- **Maintain only a Warband campaign ledger.** Best matches low administration,
  but requires custom rules for what a milestone grants and cannot automatically
  represent every normal quest reward.
- **Use no companion quest state.** Keeps the leader as the sole quest actor,
  but makes direct companion BoP rewards difficult or impossible without a
  separate reward model.

### Late-Join Catch-up

- **Share selected campaign gates.** Addresses access and attunement gaps with
  smaller scope, but does not make a companion's quest history complete.
- **Copy selected completion records when a companion joins.** Makes later
  companions appear aligned, but raises reward duplication and choice-history
  questions.
- **Grant an explicit catch-up package.** Is easier to communicate and audit,
  but can feel artificial and needs balance rules.

### BoP Rewards

- **Keep normal BoP and award equipment to eligible companions.** Preserves
  familiar item rules, but needs a controlled reward-selection flow.
- **Create Warband-aware eligibility for selected rewards.** Reduces friction,
  but is a larger departure from WotLK item semantics and needs abuse analysis.
- **Keep BoP leader-only.** Simplest technically, but prevents companion reward
  equipment from being a natural progression path.

## Retained Brainstorming: Companion and Party Models

This section deliberately preserves wider ideas from early design discussion.
Nothing in it overrides the confirmed direction above or becomes a requirement
without a separate decision.

### Current Leading Model: What Companions Are

The current leading product model is **Warband followers / Guild Wars 1-style
heroes**. They are persistent enough to have equipment, builds, appearance, and
campaign alignment, but are not full independently managed characters from the
player's point of view. This remains open to comparison with the alternatives.

The underlying Playerbots implementation uses actual characters on the player's
account. That gives the project a possible technical substrate for equipment,
level catch-up, and internal quest-state synchronization. It does not change the
product model into independent characters and does not itself confirm that every
desired synchronization case works.

The alternatives retained for comparison are a fully independent
persistent-character roster and completely abstract followers with no individual
equipment or build. The remaining open question is how much hidden state is
necessary to make the follower model work reliably.

### How Companions Progress

- **Normal group experience:** companions grow through ordinary party play.
- **Catch-up progression:** companions can approach the leader's level after
  joining or returning to the roster.
- **Level scaling:** companions scale with the leader rather than maintaining
  ordinary levels.
- **Mixed progression:** normal growth remains the default, with an explicit
  and optional catch-up rule.

The level-15 full-party milestone is still the intended party-growth target. It
does not choose a progression model for late additions. A key test for the
follower model is whether a newly acquired follower can become useful in the
leader's current campaign without requiring the player to replay its level or
quest log.

### How Quests Work

- **Independent quest state:** each character tracks quests normally.
- **Eligible party credit:** the party receives credit when the leader completes
  eligible objectives.
- **Separate companion activity:** companions can pursue activities while the
  leader follows the main story.
- **Optional quest-log visibility:** quest state can be visible when useful
  without making player administration of companion logs the progression rule.

The preferred leader-only objective flow remains the current direction. The
choices above remain useful alternatives if it cannot produce a low-friction,
reliable experience.

### How Loot Works

- **Ordinary binding:** retain normal loot rules and use the existing eligible
  group-loot trade window wherever it applies.
- **Warband assignment:** useful items belong to the Warband and can be assigned
  to its roster.
- **Tokens or a shared armory:** replace selected equipment drops with a shared
  progression resource.
- **Broader binding changes:** make some or all items less restrictive, including
  the option to remove BoP entirely.

These approaches differ in their treatment of unique items, quest rewards,
duplication, item choices, and the amount of party inventory management they
create. No Warband loot rule has been selected.

### How the Party Is Managed

- a stable active team with a bench;
- companion swaps at chosen times;
- changing which character the player directly controls; or
- saved party compositions for exploration, dungeons, and raids.

None of these party-management models is selected. They should be evaluated for
whether they deepen tactical party play without reintroducing general companion
character maintenance.

### Experience Shapes to Compare

The broader experience could be framed as:

- **WoW with a controllable party;**
- **a hero-collection RPG inside WoW;** or
- **a blend of both.**

One illustrative, non-binding combination is persistent Warband heroes, normal
party quest credit where it works, no player-facing requirement to synchronize
quest logs, and a Warband loot rule that can assign useful drops to the intended
companion. This could preserve the feeling that a team grows together without
requiring every companion to operate as an independent questing player.

Before selecting a model, assess its consequences for loot, leveling, questing,
party size, difficulty, character switching, and player-management burden.

## Decision Discipline

Settle scope one point at a time. For each topic, record:

1. the player problem;
2. the practical alternatives;
3. benefits, costs, and technical constraints;
4. the confirmed decision, if any; and
5. deferred questions.

Do not promote a preferred behavior, an existing tool capability, or a technical
shortcut into a requirement before it has been explicitly confirmed.

## Solo Quality-of-Life: Addon and Module Scope

### Confirmed Technical Context

The supported client target is **WotLK 3.3.5a, build 12340**. The server uses
the `mod-playerbots/azerothcore-wotlk` Playerbot fork, rather than stock
AzerothCore. It already includes Playerbots, the MultiBot Bridge, ALE, and the
separate server-wide `mod-progression` module.

Compatibility labels in the AzerothCore catalogue are not enough to establish
compatibility with this installation. A candidate must be checked against the
pinned Playerbot-fork revision, existing modules, required SQL/configuration,
and any required client data. Client addons must additionally target the
3.3.5a Lua/API level (normally `Interface: 30300`).

### Client Addons and Server Modules

These are distinct kinds of additions and should not be described
interchangeably:

- A **client addon** is local UI/Lua code. It can improve information display,
  searches, workflows, and client-permitted interactions. It cannot change
  server-owned quest state, BoP rules, Playerbot AI, auction inventory, or loot
  eligibility.
- A **server module** changes server behavior. It can change those rules, but
  normally needs source integration, a rebuild, configuration and/or database
  changes, and a restart.
- A server module can ship a **companion client addon**. That does not make its
  gameplay behavior client-side. AuctionSim's GM configuration UI is an example.

No addon or module installation, client-data patch, server configuration change,
or implementation work is authorized by this design record.

### Confirmed Quality-of-Life Boundaries

Solo quality-of-life may reduce repeated interface work, but it must not turn
companions into independent characters that the player is expected to maintain.
In particular:

- companion equipment, talents/builds, and appearance remain appropriate
  player-facing concerns;
- routine companion inventory, banking, professions, crafting, and independent
  quest administration remain outside the intended experience;
- a tool's existing capability does not establish a product requirement; and
- loot automation must preserve deliberate equipment and BoP decisions rather
  than silently creating an uncontrolled companion-inventory system.

The existing MultiBot and Playerbot Manager sources are useful technical inputs.
MultiBot already exposes structured loot profiles plus equipment, talent, and
outfit controls, but it also exposes inventory, banking, and profession tools.
Only the former set is aligned with the current product direction; the latter
does not become part of the intended experience by being available.

### Shortlist: Candidates Worth a Deliberate Later Decision

None of these is selected or installed. They are the current candidates that
fit the design best if their exact compatibility is later confirmed.

#### AH Bot Plus

**Type:** Server module. It populates the Auction House with configurable
listings and optional purchasing behavior.

**Status:** Preferred standard-Auction-House candidate. The intended experience
is that the player can both buy useful items and sell eligible items without a
detailed market simulation. Its seller and buyer behavior must both be evaluated
and configured; a seller-only population module would not meet the selling goal.
It is not remote Auction House access and requires bot-character plus
pricing/category configuration.

Source: [NathanHandley/mod-ah-bot-plus](https://github.com/NathanHandley/mod-ah-bot-plus)

#### Transmog

**Type:** Server module. It lets the player shape companion appearance.

**Status:** Strong fit with the confirmed appearance goal. It requires an exact
fork-revision check, module data/configuration, rebuild, and an in-world
service/NPC.

Source: [azerothcore/mod-transmog](https://github.com/azerothcore/mod-transmog)

#### Auctionator 3.3.5a Backport

**Type:** Client addon candidate. It improves Auction House searching, price
history, shopping lists, and posting workflow.

**Status:** A client-only complement to one server-side AH population module.
It cannot populate the AH or change its rules. Treat third-party 3.3.5
backports as candidates to verify in a separate client copy before adoption.

Source: [JedborgWoW/Auctionator-3.3.5a](https://github.com/JedborgWoW/Auctionator-3.3.5a)

#### SpeedyAutoLoot for WotLK

**Type:** Client addon candidate. It speeds up clearing an opened loot window.

**Status:** Narrower and safer than a server-wide loot rewrite, but it cannot
alter party eligibility, BoP, or role-aware item routing. Verify its 3.3.5a
behavior before use.

Source: [tje3d/SpeedyAutoLoot-Wotlk](https://github.com/tje3d/SpeedyAutoLoot-Wotlk)

### Options That Do Not Fit the Current Scope

The following are not current candidates. This is a scope assessment, not a
claim that they are inherently bad tools.

- [Individual Progression](https://github.com/ZhengPeiRu21/mod-individual-progression)
  creates individual character progression and catch-up rules. It conflicts with
  the preferred shared-Warband campaign direction and is distinct from the
  existing server-wide `mod-progression` module. Do not add another progression
  model while campaign sharing is unresolved.
- [AuctionSim](https://github.com/Moloch17/mod-auctionsim) intentionally
  simulates a living economy using observed market data, auction scans, buying,
  bidding, and optional market personas. That is more simulation than the
  intended straightforward buy-and-sell experience, so it is not the current AH
  candidate.
- [Ollama Chat](https://github.com/DustinHendrickson/mod-ollama-chat) adds
  LLM-backed Playerbot chat and personalities, not loot or combat-role
  management. It introduces model hosting, dependencies, and performance
  concerns.
- [Dungeon Clear](https://github.com/jrad7/mod-dungeon-clear) may be a future
  accessibility mode, but its autonomous routing, pulling, looting, and recovery
  shifts play from leading a hero party toward supervising automation.
- [ARAC](https://github.com/heyitsbench/mod-arac) is unrelated to the Warband
  goal and requires client `Patch-A.MPQ` and server DBC changes.
- [NPC Services](https://github.com/azerothcore/mod-npc-services) bundles
  conveniences with broad shortcuts, including instance and cooldown resets,
  banking, mail, and talent reset. It is too broad to adopt for one convenience.
- [Junk to Gold](https://github.com/noisiver/mod-junk-to-gold) permanently sells
  every gray item at loot time. A vendor-only, reviewable junk-sale workflow
  would be safer if this problem becomes important.
- [Quest Loot Party](https://github.com/pangolp/mod-quest-loot-party) depends
  on an upstream change that is not yet present. Even if available, it only
  distributes quest items to active quest holders; it does not solve synchronized
  objectives, turn-ins, BoP rewards, or campaign sharing.
- [DungeonRespawn](https://github.com/AnchyDev/DungeonRespawn) is archived, and
  its death-to-entrance teleport removes normal party recovery and wipe stakes.
- [No Hearthstone Cooldown](https://github.com/BytesGalore/mod-no-hearthstone-cooldown)
  substantially changes travel pacing. Its stated core-version requirement must
  be verified against the Playerbot fork before it can be considered.
- [AoE Loot](https://github.com/TerraByte-tbwps/mod-aoe-loot) is highly relevant
  in principle, but its current README explicitly says it is broken after packet
  changes. It is not a viable current solution.
- [Auto Gather](https://github.com/thanhtong89/mod-auto-gather) bypasses
  gathering and skinning loops, changes resource flow, and is not part of the
  combat-companion scope.

### Defined Direction: Auction House and Loot

#### Standard Auction House

The preferred standard-Auction-House experience is now defined as:

- the player can buy useful items; and
- the player can list and sell eligible items.

The goal is dependable solo convenience, not an in-depth market simulation.
AH Bot Plus is the current module candidate because it can be configured for
listing and purchasing behavior. AuctionSim is explicitly not the preferred
direction. Exact item categories, price rules, buyer behavior, and progression
limits remain implementation choices to settle later.

Remote/portable Auction House access is not selected and is a separate travel
and world-convenience decision. Neither AH Bot Plus nor AuctionSim supplies it.

#### Black AH

"Black AH" is recorded here as the **Black Market Auction House** unless a
different feature was meant. This is a desired convenience, not a confirmed
technical solution. It must be investigated separately from the standard Auction
House because the evaluated AH population modules operate on normal faction or
neutral Auction Houses, not a Black Market system.

Open questions include:

- whether the target experience is buying and bidding only, as in the usual
  Black Market model, or whether player selling is also intended;
- whether a compatible WotLK 3.3.5/Playerbot-fork implementation exists without
  client-data changes; and
- which item pool, prices, timing, and progression limits would preserve the
  intended equipment journey.

#### Loot Handling

No evaluated module currently provides a safe, role-aware equipment distribution
system for a Warband party. The design problem remains open:

- Who owns ordinary drops by default: leader, eligible companion, or a role
  policy?
- How are usable upgrades presented and assigned without requiring general
  companion inventory management?
- Which items, if any, may be auto-sold, and which must be protected from
  automation?
- How do quest items and BoP rewards interact with synchronized companion
  eligibility and the desired leader-only objective flow?

Client-side faster-loot tools can reduce clicking after an eligible loot window
opens. They cannot answer any of those server-owned questions. The broken AoE
loot module and the overly broad immediate junk-sale module are not substitutes
for a loot policy.

## Next Discovery Topic

Settle the Auction House purpose first, then define the loot policy one point at
a time. Once those decisions exist, examine the selected candidate's exact
Playerbot-fork compatibility, dependencies, and setup work before authorizing
any installation or configuration change.
