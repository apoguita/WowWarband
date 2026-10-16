# WoW Warband: Product Direction

**Status:** active design direction  
**Last updated:** 16 October 2026

**Implementation boundary:** Product direction is implemented in WoW
Warband-owned server code and, when needed, a Warband-owned client addon/plugin.
Third-party modules and addons in the research remain references unless a
specific capability is separately selected and verified. See the
[implementation policy](Warband-Implementation-Policy.md).

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

The campaign is built around a **five-member group total**: the leader and four
AltBot followers. This is the party-size model for outdoor play and dungeons.
Raid content is a later goal, but it must be downscaled or otherwise adapted so
that this same five-member Warband can complete it. The adaptation method,
difficulty, rewards, and raid-specific exceptions remain open implementation
questions; expanding to a conventional raid-sized group is not the direction.

### Character and Profession Availability

Character creation should have no WotLK race/class pairing restrictions: the
player should be able to create combinations unavailable in the original game,
such as a Human Shaman or an Undead Paladin. This is specifically about opening
race/class combinations, not merely making every class or profession available
somewhere. ARAC is the current implementation for that goal. Its world SQL and
matching server/client DBC assets have been applied to the local runtime without
a C++ build, but creation of these specific combinations has not yet been
verified in-game; end-to-end compatibility remains unconfirmed.

Separately, all primary and secondary professions should be available to the
player. This does not make profession progression or management part of the
companion experience: follower professions remain outside the intended
player-facing scope. AzerothCore already exposes a setting for the number of
primary professions; both the project template and local runtime configuration
now allow all 11. The runtime setting takes effect on the next worldserver
start and has not yet been tested after restart.

### Binding-Free Item Ownership

Item binding is not part of the intended single-player experience. The leader
must be able to pass items among the Warband roster as they see fit. Bind on
Pickup, Bind on Equip, Bind on Use, enchant-caused binding, and existing
soulbound state must not prevent that transfer.

This is an item-ownership decision, not a decision to expose follower bags as a
player-management system. The player directs equipment to the appropriate
follower; the underlying item movement may be handled by a UI or automation.

The core item layer has no Warband context, so the implementation applies this
binding-free rule to the entire local realm. That matches the project's
single-player scope; it must be revisited if the realm ever permits unrelated
human players.

Quest ownership, unique-item limits, keys, inventory capacity, equipment
requirements, Auction House rules, and reward choice are separate mechanics.
They must be handled deliberately where relevant, but they are not reasons to
retain an item-binding barrier.

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
keep a follower aligned with the leader's campaign, access gates, or reward
delivery. The design aim is that hidden technical state should not make the
player accept, track, abandon, or turn in routine quests for each follower.

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
is a complete five-member group, including the leader, unlocked by level 15.

Open design detail: the document does not yet choose the precise unlock cadence,
eligibility rule, or whether every unlock is fixed, role-selected, or otherwise
earned.

#### Level catch-up direction

Every newly recruited follower begins as a real level-1 character. The leader
does not directly set a follower's level and followers do not level-scale to the
leader. Instead, while a follower is below the leader's level, it should receive
an XP catch-up multiplier that grows with the level gap. The multiplier stops
being a catch-up benefit once the follower reaches the leader's level.

This is the current desired behavior, not a live rule. The XP sources affected,
the multiplier curve and cap, handling when the leader levels ahead again, and
whether catch-up is automatic or visible as a choice remain technical and
balance questions. The intent is clear: a late level-1 follower becomes useful
through accelerated ordinary progression, without the player replaying its
entire history.

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
to enable this flow, catch-up, reward delivery, or another confirmed design
goal.

For this purpose, a follower quest log is **non-authoritative**: it is hidden
technical state, not the record that controls campaign pace. The leader's
campaign decisions and completions rule. A follower may retain whatever quest
entries the server needs to make eligibility, turn-in, rewards, or access work,
but the player must not need to make its counters or history match the leader's
before it can participate.

### Current Quest-Progression Hypothesis

The leader owns the campaign pace. A follower should be able to join after the
campaign has begun, become aligned enough to participate in the leader's current
story, and remain aligned as the leader advances. The player should not have to
replay the campaign separately for each follower.

The current candidate behavior is:

1. on recruitment, create the follower at level 1 and give it the level-gap XP
   catch-up behavior described above; and
2. during play, give the follower any eligible internal quest state it needs,
   but let only the leader perform objectives and drive turn-ins; then
3. complete the follower's eligible quest and reward path when the leader turns
   in, even if the follower's own objective counters are incomplete.

This is a desired behavior, not a claim that it works universally today.
Playerbots' existing quest synchronization is promising evidence for the
turn-in portion. Level-gap XP catch-up, prerequisite handling, the internal
quest entries needed, quest choices, rewards, and exceptions still need separate
design and runtime validation.

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

## Binding-Free Items: Implementation Boundary

The binding-free ownership policy removes BoP as a reason to give a follower an
independent quest history. A quest reward received by the leader can be routed
to the appropriate follower, so internal companion quest state is needed only
where access or reward delivery itself requires it.

This requires server-side work; a client addon cannot change binding behavior.
The catalogue has no maintained module that covers every AzerothCore binding
path.

The in-repository `modules/mod-warband` module clears existing soulbound flags
when a character logs in and after normal item-acquisition paths. There is no
in-house core change: nothing in this repository prevents the core from setting a
soulbound flag, and no in-house patch removes soulbound or enchant binding as a
transfer restriction. The module clears the flag after the fact instead, and it
is compiled into the current build; the behaviour itself has not been verified in
game.

The implementation still needs focused in-game validation for newly acquired,
already-owned, quest, equipped, enchanted, mailed, and group-roll items. It
must also define non-binding behavior such as unique limits, keys, inventory
space, equipment restrictions, mailing, and Auction House eligibility. Those
questions constrain the transfer workflow; they do not reintroduce binding.

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
  reputation, experience, and unique-item limits. Each needs defined behavior
  before a reward model is chosen; item binding must not decide the recipient.
- Current AltBot reward behavior can auto-select rewards according to the
  Playerbots setting. That existing behavior is not yet a suitable product
  decision for role-directed companion equipment.

### Feasibility Assessment

The desired "leader completes objectives; companion completes and turns in"
behavior has a plausible existing foundation in Playerbots. It is not yet
confirmed as a reliable AltBot experience for every quest type, nor does it
solve late-join catch-up or reward delivery by itself. Validation should be a
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
  but can make direct follower reward delivery difficult without a separate
  reward model. It does not prevent the leader from routing an item afterward.

### Late-Join Catch-up

- **Current desired rule: level-gap XP catch-up.** A follower starts at level 1
  and gains increasingly accelerated XP while behind its leader, then returns to
  normal progression at level parity. This preserves ordinary levels rather than
  copying a level or using permanent scaling. The curve and qualifying XP sources
  are still open.
- **Share selected campaign gates.** Addresses access and attunement gaps with
  smaller scope, but does not make a companion's quest history complete. This
  may complement level catch-up because level alone does not grant access.
- **Copy selected completion records when a companion joins.** Makes later
  companions technically eligible, but raises reward duplication and
  choice-history questions. It is not needed merely to make a follower level up.
- **Grant an explicit catch-up package.** Is easier to communicate and audit,
  but is an alternative to XP catch-up only if accelerated XP proves unsuitable.

### Quest Rewards

Binding does not limit who can receive an item after it enters the Warband.
Remaining choices concern reward selection, unique limits, quest-use items, and
whether a follower needs internal quest eligibility to receive a reward directly
rather than receiving it from the leader afterward.

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

The current direction is real level-1 followers with a level-gap XP multiplier,
not direct level copying or permanent level scaling. Normal play remains the
source of their progression; the open design work is the catch-up curve and
which XP sources it modifies.

The level-15 full-party milestone remains the intended party-growth target. A
key test is whether a newly acquired follower becomes useful in the leader's
current campaign without replaying its level or quest log.

### How Quests Work

The leader is the only campaign authority. A follower's quest log is allowed as
hidden server machinery, but it is not a progression track the player manages
or needs to make complete. The desired flow is eligible party credit and
completion at the leader's turn-in; separate companion questing is outside the
direction.

The remaining technical question is not whether followers need a player-facing
quest log, but the smallest internal quest state that safely supports access and
rewards.

### How Loot Works

Binding-free transfer within the Warband is confirmed. Useful items can be
assigned to the roster without BoP/BoE or other binding rules deciding their
destination.

Open workflow alternatives are:

- **Warband assignment:** useful items belong to the Warband and can be assigned
  to its roster.
- **Tokens or a shared armory:** replace selected equipment drops with a shared
  progression resource.

These approaches differ in their treatment of unique items, quest rewards,
duplication, item choices, and the amount of party inventory management they
create. They do not change the binding-free ownership rule.

### How the Party Is Managed

- a stable active team with a bench;
- companion swaps at chosen times;
- changing which character the player directly controls; or
- saved party compositions for exploration, dungeons, and future five-member
  raid-adapted content.

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
- loot automation must preserve deliberate equipment and recipient decisions
  rather than silently creating an uncontrolled companion-inventory system.

The existing MultiBot and Playerbot Manager sources are useful technical inputs.
MultiBot already exposes structured loot profiles plus equipment, talent, and
outfit controls, but it also exposes inventory, banking, and profession tools.
Only the former set is aligned with the current product direction; the latter
does not become part of the intended experience by being available.

### Shortlist: Candidates Worth a Deliberate Later Decision

None of these is selected or installed. They are the current candidates that
fit the design best if their exact compatibility is later confirmed.

#### Normal Auction House bot options

**Type:** Server module. It populates the Auction House with configurable
listings and optional purchasing behavior.

**Official `mod-ah-bot`:** Its source is now pinned in the repository. Upstream
supports seller and buyer behavior independently and requires world SQL plus a
configured bot account/character. Its documented minimum core commit is an
ancestor of this checkout. It has not been built, configured, enabled, or tested
here.

Source: [azerothcore/mod-ah-bot](https://github.com/azerothcore/mod-ah-bot)

**`mod-ah-bot-plus` alternative:** A second seller/buyer candidate with similar
purpose; its source is not pinned. These are alternatives, not modules to stack.
The intended standard-AH experience is that the player can buy useful items and
sell eligible items without a detailed market simulation. Evaluate the simple
seller/buyer configuration that best serves that loop. Neither module provides
remote Auction House access or Black Market behavior.

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
- [ARAC](https://github.com/heyitsbench/mod-arac) directly supports the desired
  unrestricted race/class character creation, including Human Shamans and
  Undead Paladins. Its world SQL and DBC assets are now installed in the local
  runtime, with the client patch added as `patch-z.mpq` so the existing
  `patch-a.mpq` remains untouched. The database now contains all 100 WotLK
  race/class combinations. The client/server data pairing and actual character
  creation still need in-game verification.
- [NPC Services](https://github.com/azerothcore/mod-npc-services) bundles
  conveniences with broad shortcuts, including instance and cooldown resets,
  banking, mail, and talent reset. It is too broad to adopt for one convenience.
- [Junk to Gold](https://github.com/noisiver/mod-junk-to-gold) permanently sells
  every gray item at loot time. A vendor-only, reviewable junk-sale workflow
  would be safer if this problem becomes important.
- [Quest Loot Party](https://github.com/nexartgroup/mod-quest-loot-party) has a
  fork that says the old upstream hook dependency is obsolete and offers quest
  item sharing, forced quest drops, and an optional same-loot personal mode.
  The quest options still require recipient quest state; the personal mode
  copies the same eligible drops to every member rather than assigning gear by
  role or rolling independently. It does not solve leader-only turn-ins and can
  multiply loot and follower bag pressure, so it remains an unselected
  experimental option.
- [mod-dead-means-dead](https://github.com/kjack9/mod-dead-means-dead) prevents
  creature respawns in dungeons and raids by default. Its README documents an
  instance-unload limitation; compatibility and that lifecycle behavior remain
  to be checked.
- [DungeonRespawn](https://github.com/AnchyDev/DungeonRespawn) is a separate,
  archived character-recovery candidate that returns the player to the dungeon
  entrance after death. Keep it distinct from stopping instance creatures from
  respawning; compatibility remains unverified.
- [No Hearthstone Cooldown](https://github.com/BytesGalore/mod-no-hearthstone-cooldown)
  substantially changes travel pacing. Its stated core-version requirement must
  be verified against the Playerbot fork before it can be considered.
- The older [TerraByte AoE Loot port](https://github.com/TerraByte-tbwps/mod-aoe-loot)
  was reported broken after packet changes. That is distinct from the official
  AzerothCore `mod-aoe-loot` source now staged in this repository; the staged
  version remains unbuilt and needs compatibility/gameplay validation.
- [Auto Gather](https://github.com/thanhtong89/mod-auto-gather) is staged as an
  optional leader convenience because gathering automation was requested. It
  changes the ordinary gathering loop and its PlayerScript also runs for bots
  with matching skills, so it must not be mistaken for a follower-profession
  feature or enabled without deciding bot behavior.

### Defined Direction: Auction House and Loot

#### Standard Auction House

The preferred standard-Auction-House experience is now defined as:

- the player can buy useful items; and
- the player can list and sell eligible items.

The goal is dependable solo convenience, not an in-depth market simulation.
The official `mod-ah-bot` source is pinned for the eventual build review; the
un-pinned `mod-ah-bot-plus` remains an alternative. Choose at most one after
comparing their seller/buyer behavior and setup. AuctionSim is explicitly not
the preferred direction. Exact item categories, price rules, buyer behavior,
and progression limits remain implementation choices to settle later.

The existing Playerbots source does not supply a no-build shortcut: its
`LootAction.cpp` contains an `AuctionItem` helper, but that code is block
commented and is not exposed as an active AH setting. Normal AH buy/sell still
requires one of the separate candidates or a Warband implementation.

Remote/portable Auction House access is not selected and is a separate travel
and world-convenience decision. Neither AH bot candidate nor AuctionSim supplies it.

#### Black Market Auction House

"Black AH" is recorded here as the **Black Market Auction House**. A specific
candidate has now been found: [Youpeoples/Black-Market-Auction-House](https://github.com/Youpeoples/Black-Market-Auction-House)
provides an Eluna server script and a matching client addon for configured
listings, bidding, refunds, and mailed wins. It is not installed or validated
in the running server/client, though its source is now pinned in this repository.
It provides bids on preconfigured listings, not a player-facing way to post
items for sale, so it does not yet satisfy the requested buy-and-sell
capability. The current direction is to **hold this candidate inactive until
both buying and selling are supported**. This is a scope decision; whether to
extend the script or implement a different solution remains open.

The pinned script's configured test vendor (`2069430`) is absent from the local
world data, and the source does not include SQL to create or spawn that NPC. The
local ALE source exposes the principal Lua API names used by the script,
including whisper event 19 and creature-gossip registration, but runtime
compatibility is still untested because ALE diverges from standard Eluna. It is
not activated: loading it creates a character-database table and starts auction
timers even before a usable vendor is available.

Implementation questions after that requirement is met include:

- how player listings/sales should work alongside bids on configured listings;
- where to put a dedicated vendor: next to a capital Auction House for
  convenience, in a less accessible location for flavor, or use a custom UI
  entry point instead; reusing a normal auctioneer risks replacing its normal
  gossip behavior;
- whether the candidate's Eluna-origin script and client UI work with the
  installed ALE/AzerothCore and 3.3.5 client versions;
- whether its item pool, prices, auction timing, and progression limits fit the
  desired gear journey; and
- how it should coexist with the separate standard Auction House buy/sell
  solution. A custom extension or a separate Warband implementation may be
  needed if the backport cannot support player selling cleanly.

#### Loot Handling

No evaluated module currently provides a safe, role-aware equipment distribution
system for a Warband party. Several supporting sources are now pinned in the
repository but remain unbuilt and inactive: AoE Loot combines nearby corpses,
Bot Inventory Master exposes commands for same-account bot gear/bags, and Junk
to Gold Plus sells protected gray loot. None chooses the right equipment
recipient or defines a fully automatic Warband loot policy. The design problem
remains open:

- Who owns ordinary drops by default: leader, eligible companion, or a role
  policy?
- How are usable upgrades presented and assigned without requiring general
  companion inventory management?
- Which items, if any, may be auto-sold, and which must be protected from
  automation?
- How do quest-use items and reward delivery interact with synchronized
  companion eligibility and the desired leader-only objective flow?

Client-side faster-loot tools can reduce clicking after an eligible loot window
opens. They cannot answer any of those server-owned questions. Collection,
cleanup, and bag-control tools are not substitutes for a loot policy.

## Next Discovery Topic

Continue the source compatibility review and stage useful modules together,
while keeping conflicting loot/economy choices open. Do not apply module
configuration or SQL, alter client/server runtime data, or build until the
supervised final integration step.
