WoW Warband client addon

A settings window with a feature tree on the left and a detail pane on the right.

Open it with the chat command /warband or /ww, or by clicking the compass icon next to the
minimap. There is no default key binding: "Toggle the Warband window" is listed in the Key
Bindings window if you want to assign one yourself. Escape and the close button close it. The
window can be dragged and remembers where you left it.

The tree as it stands:

    Server
      XP Options          live - the multiplier and the follower catch-up controls
      Follower gathering  live - the skill mirror, with an Apply button
      Item binding        live - the party binding policy switch
      Magic find          live - one multiplier per quality
      Gold find           live - the coin multiplier
      Supplier prices     live - what the supplier merchants charge and pay, with Apply
      Trash sell          live - grey loot sold on pickup, with a sweep button
      Instances           live - killed instance creatures stay dead, with a counter
      World scaling       live - the open-world scaler switch, off by default
      AoE loot            live - the area looting switch, off by default
      World bots          live - the random bot population, its switch and target
      Convenience         live - hearthstone without a cooldown, pets always happy
    Features              what this Warband adds, listed live
    About                 author and project description

Label colours state the status: green is live, grey is an unfinished placeholder. The detail pane
header repeats it in words, so a placeholder never reads as finished. An unfinished feature sits
inside the tab it belongs to rather than getting a tab of its own.

Every value the panel changes is saved on the server, in the world database, so a restart keeps it.
The panel always shows what the server accepted, never what it hoped to set.

The **Features** page lists every feature the module adds, not only the switches that happen to be
on: experience and catch-up, gathering, gear sharing, magic find, gold find, trash sell, auction
house, instances, hearthstone, pets, world scaling, AoE loot, world bots, the trade gold panel and
the party roster. Each line follows the live state where the server reports one, so the page is a
statement about the running server rather than a brochure.

The inner panes are border-only group boxes on purpose: no backdrop background, so the window
behind them shows through instead of a grey wash on top of it.

The XP Options tab reads and updates the live multiplier through the server module's chat
protocol:

    .warband xp             the module replies WARBAND_XP=<rate>
    .warband xp set <1-10>  applies the new rate immediately, then replies the same way

The slider sends the value when you release it; the -/+ buttons and the 1x / 2x / 5x / 10x presets
send on click. The status line shows what the server answered, or says so when the worldserver does
not answer at all. Changes are runtime-only: a worldserver restart or config reload returns the rate
to the configured default (2x).

The Features list shows the live rate, so it updates as the slider moves.

## Follower catch-up

The same tab carries the follower catch-up controls and readout. The server reports its settings
as `WARBAND_CATCHUP=...` in reply to `.warband catchup`, and the panel shows them as a live line
(for example "+0.10 per level behind, floor 1.00, uncapped").

Controls, one click each, each sent as a `.warband catchup` command:

| Control | Range | Step per click |
|---|---|---|
| Catch-up: on / off | - | toggles the bonus |
| Extra per level behind | 0.00 - 1.00 | 0.05 |
| Lowest multiplier | 1.00 - 10.00 | 0.50 |
| Highest multiplier | uncapped, then 0.50 - 20.00 | 0.50 |

Every click sends one command, and the server's reply carries the whole new state, so the panel
never has to guess what took effect. The values are runtime-only: a worldserver restart or
`.reload config` returns them to the module configuration.

The level gaps underneath are read from your own party on the client, so they stay current without
asking the server: each follower is listed with how far behind it is and the multiplier it
therefore receives.

## Follower gathering

Server > Follower gathering reads the mirror state through `.warband gather status` and shows the
leader values the companions receive: Herbalism, Mining and Skinning, plus whether the mirror is
enabled and whether it applies automatically.

Apply sends `.warband gather`, which mirrors on the spot and answers with the whole new state, so
the page reports the number of followers changed by that click instead of assuming it worked. When
the values are all zero the page says so plainly: there is nothing to mirror yet, because the
leader has no gathering profession.

Applying by hand is the exception rather than the routine. The server keeps the party in step by
itself - on leader login, when a companion joins the party, and whenever a gathering skill changes
while playing - so the page states that in its status line ("raised only, kept in step on login,
join and every skill change") and the button is there for the case where a follower was out of
range, on another map, or joined while the mirror was switched off.

The rule is a floor, never a ceiling: companions are only ever raised. A member that trained
further, or that was the character the player logged in as in an earlier session, keeps its own
value and is never dragged down, which is what makes swapping which party member is played safe.
The hint text on the page says so, because a player who sees a low leader value should not expect
their own higher skill to disappear.

This page is the client half of the feature. Mirroring itself is server side, so the page needs a
worldserver built with the Warband module. The on-demand apply has been verified in game; the
automatic sync is built but not yet verified. The test plan, including the GM commands for giving
the leader a profession and for checking the floor, is in
`.agents/plans/warband-gathering/warband-gathering.TESTING.md`.

Files:

    Warband.lua     behaviour: tree model, page rendering, chat protocol, minimap button,
                    slash commands, window plumbing
    Warband.xml     layout: window chrome, tree pane, detail pane, the feature pages
    PartyAccess.lua member strips on the bag frame and the character sheet
    PartyRoster.lua the Party tab on the Friends frame
    Layout.lua      makes the bags, the character sheet and the Friends frame draggable
    Bindings.xml    the WARBANDTOGGLE key binding entry, unbound by default

Adding a feature means adding a node to the Tree table in Warband.lua. Use status "live" only for
something that actually works, and "placeholder" for anything unfinished.

## Item binding

Server > Item binding reads the policy with `.warband binding` — the reply is
`WARBAND_BINDING=enforced=0` — and one button flips it. With binding **off**, which is the default,
a soulbound piece can be traded, mailed, auctioned, put in a guild bank and handed to any character
— a follower, an alt outside the group or anybody else — like any other item; the soulbound bit is
removed from the carried item while the rule is off, so the client offers it in every trade window
(it no longer reads "Soulbound"). Turning it **on** restores the ordinary rule. The page states the
policy in words rather than in yes/no, because "binding off" is easy to misread as "items are
unbound".

## Magic find

Server > Magic find shows five rows — green, blue, purple, orange, gold — each with a `-` and a `+`
(step 0.5, range 1 to 20) and a reset button that clears all five. Values are multipliers on the
drop chance of that quality only: x4 turns a 20% blue into 80%, x6 turns a 3% legendary into 18%,
and anything past 100% becomes a guaranteed drop. The reply is
`WARBAND_MAGICFIND=green=2.00;blue=4.00;purple=6.00;orange=6.00;gold=6.00`, and a worked-example
line recalculates as you click. Poor and normal qualities are never touched, and no rows are added
or removed.

## Gold find

Server > Gold find is one row: `-` and `+` in steps of 0.5 between 1 and 20, plus a reset. The reply
is `WARBAND_GOLDFIND=3.00`. It multiplies the coin that loot generates — creatures, chests, mines
and containers — and leaves vendoring, quest rewards, mail and the auction house alone.

## Supplier prices

Server > Supplier prices is what the Warband suppliers charge and pay. Eight rows — poor, normal,
uncommon, rare, epic, legendary, artifact, heirloom — each with `-` and `+` in steps of 1 between 1
and 20, then a floor row in copper, then **Apply prices** and **Reset to defaults**. The reply is
`WARBAND_SUPPLIER=poor=2.00;...;heirloom=9.00;floor=10;items=7351;current=1`.

A supplier's price is `max(floor, the item's original sell price * the multiplier for its quality)`,
and the same price is charged and paid, so nothing can be bought low and sold high. The page never
shows a value it has not been told: every click asks the server and displays what came back.
`current=1` means the item prices already match the values shown.

**Apply prices writes the prices onto the items**, and the server reads an item's price once at
startup — so the page says plainly that the new prices appear in game after the worldserver
restarts. Nothing re-prices on its own; a restart with no Apply changes nothing. The values
themselves are saved by the server, so they survive that restart and the page shows them again next
time.

## Trash sell

Server > Trash sell has the switch and a **Sell the junk in our bags now** button. The switch sells
grey loot at the moment it is picked up, for the leader and every companion, and the vendor price
is paid into the leader's purse - the one purse the party can see. The button sweeps what is
already in the bags, which is the only way to clear a companion that filled up before the feature
was on. The reply is `WARBAND_TRASHSELL=enabled=1;sold=12;copper=3456;swept=0`; the page shows this
Warband's totals since the leader logged in, plus how many items the last sweep collected.

## Instances

Server > Instances is one switch and a counter: a creature killed inside a dungeon or raid stays
dead for the run, and the counter shows how many that session has kept down. The reply is
`WARBAND_INSTANCE=enabled=1;kept=42`. The hint on the page says the part people get wrong — an
instance reset (manual, or the daily one) still restores the whole dungeon, which is what a reset
means.

## World scaling

Server > World scaling is one switch over the open-world scaler, `mod-zone-scaling`. The reply is
`WARBAND_WORLDSCALE=installed=1;enabled=0`, and the switch flips the module's own
`ZoneScaling.Enable` option without touching anything else in its file. It is **off by default**:
the module ships disabled, and even enabled it only scales zones the server has opted in — so the
page's hint says the switch alone does not change the world. When the server was built without the
module the reply is `installed=0` and the page says so instead of offering a dead button.

## AoE loot

Server > AoE loot is the full configuration surface over the looting module, `mod-aoe-loot`. The
page carries the master switch, **Login message** (announce on login), **In group** (merge inside a
party too), **Mail when full** (mail an item when the bags are full instead of losing it), a merge
radius stepper (5–100 yards, step 5) and a corpse-count stepper (1–50, step 1). The reply is
`WARBAND_AOELOOT=installed=1;enabled=0;message=1;group=1;mail=0;range=55.0;corpses=20`. Everything
is **off by default** for the master switch: the module ships enabled, so the Warband runtime seeds
its configuration with 0 and the base game's one-corpse window stays the default until you turn it
on. Each character can additionally toggle the feature with `.aoeloot on/off`. When the server was
built without the module the reply is `installed=0` and the page says so.

## World bots

Server > World bots is the switch and target for the random bots the playerbots module logs in and
out by itself — ambience, not the Warband. The reply is
`WARBAND_RANDOMBOTS=enabled=1;target=500;online=123`. **Random bots: on/off** turns the whole
population off (the ones online are logged out at once) or back on; the target stepper (1–500, step
10) pins how many stay online. The Warband's own companions are never random bots, so the switch
cannot touch the party. Both choices are written into the playerbots configuration, so they survive a
restart; the default until you touch it is the playerbots configuration, unchanged.

## Trade gold panel (`TradePanel.lua`)

A small frame that attaches to the side of the trade window and disappears with it. It exists for one
job: letting a companion pay without reciting the bot's whisper sequence (`t <amount>`, twice, in the
right order, once the window is already open).

When a trade opens, the panel shows the partner and what they carry, three amount boxes for gold,
silver and copper, and one **Put in trade** button. Each box takes typed numbers as well as `-` / `+`
steps (gold 0–9999, silver and copper 0–99), so 2 silver is one number rather than two button presses.
Pressing the button sends `.warband trade gold <amount>`; the server puts
that much of the companion's money on their side of the trade, the amount appears in the window like
any hand-filled trade, and accepting moves the coin through the ordinary trade path. The reply is
`WARBAND_TRADEGOLD=ok=1;partner=Tanko;amount=100;purse=1240`, or `ok=0;reason=nofunds|notrade|notcompanion`
when it cannot happen — the panel then says why instead of failing silently.

Only a companion can pay this way: a bot (any Warband follower) or a character on your own account. A
real player on another account is never touched. `.warband trade` alone reports the open trade:
`WARBAND_TRADE=open=1;partner=Tanko;purse=1240;inTrade=0`.

## Convenience

Server > Convenience carries two timers a party of five cannot keep by hand. **Hearthstone** clears
the item's cooldown the moment it is used (`WARBAND_HEARTHSTONE=enabled=1;cleared=3`, with the count
of clears this session shown underneath). **Pets** keeps every hunter pet at full happiness, the
leader's included, because a follower will never feed its pet and an unhappy pet carries a damage
penalty (`WARBAND_PETS=enabled=1`).

## Party roster (`PartyRoster.lua`)

The client has no party-management window: the Friends frame's Raid tab manages raids, not who is
standing next to you. This file adds a **Party** tab there, next to Friends/Who/Raid/Guild, and it
is the one place to choose which characters on the account are with you.

    Invite   sends .playerbots bot add <name>      (the character logs in and joins the group)
    Dismiss  sends .playerbots bot remove <name>   (it logs out and leaves the group)

The roster data comes from the server, because the client cannot ask which characters an account
has: `.warband party` answers with one line per character — `name|class|level|online|grouped` —
chunked into a few chat lines and closed by an empty one. The tab shows level, class, online state
and whether the character is already grouped, then offers Invite for an offline character and
Dismiss for a running one. Refresh happens on opening the tab, on the Refresh button, after every
click, and on `GROUP_ROSTER_UPDATE`.

Two implementation notes: the tab button is created through a fallback chain
(`FriendsFrameTabButtonTemplate`, then `CharacterFrameTabButtonTemplate`, then a plain button),
because the exact template a 3.3.5 client uses is inside the MPQs and cannot be read from this
repository — the fallback keeps a wrong guess cosmetic instead of fatal. And the panel is anchored
to the Friends frame's own corners rather than given a fixed size, so it fits whatever proportions
the client uses.

## Party access and window layout

Two client features were added on 16 October 2026. Both are accepted as they stand; the
improvements listed at the end are recorded for later, not open work.

**Party access (`PartyAccess.lua`).** A strip of companion buttons rides above the bag frame and
above the character sheet. Clicking one opens that companion's window in MultiBot — the bags strip
opens the inventory, the sheet strip opens the character sheet, and shift-click flips to the other.
No protocol of our own is involved: it calls `MultiBot.RequestBotInventory(name)` and
`MultiBot.OpenCharacterInfo(name)`, so MultiBot keeps owning the traffic. The player is deliberately
*not* on the strip: MultiBot's windows are bot windows and show an empty list for a real account,
so the player's own items stay in the client's real bag frame and real character sheet.

**Window layout (`Layout.lua`).** The container frames and the character sheet are anchored by the
client and are not flagged movable, which is why dragging them did nothing. The addon now sets that
flag once at load and saves the result, so the windows move whenever they are dragged. The
character sheet needs a 10-pixel grip strip above its top edge to be grabbed at all: its body is a
full-size child frame, so every click otherwise lands on a child.

Improvements recorded for a later pass, none of them scheduled:

- MultiBot renders a follower's inventory as a list, not as a bag grid. A real grid would mean
  Warband's own bag frame, built from the module's data or the bridge's `INVENTORY_V1` payload.
- Item transfer between members is **not** built. Trading works the ordinary way: open a trade on a
  companion and it accepts. A direct move (see `mod-bot-inventory-master` for the technique) would
  need Warband server code.
- The window grip is functional but not handsome; a real grip texture, or a grab area inside the
  border, would be the cosmetic fix.
- The strip only appears when companions are in the group, and has no per-member configuration.


XP controls require a worldserver executable built with the Warband module and started after that
build. The panel is client-only: changing it needs no server build, just a client restart for the
addon files to be re-read.
