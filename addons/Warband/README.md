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
    Features              what this Warband adds, listed live
    About                 author and project description

Label colours state the status: green is live, grey is an unfinished placeholder. The detail pane
header repeats it in words, so a placeholder never reads as finished. An unfinished feature sits
inside the tab it belongs to rather than getting a tab of its own.

The inner panes are border-only group boxes on purpose: no backdrop background, so the window
behind them shows through instead of a grey wash on top of it.

The XP Options tab reads and updates the live multiplier through the server module's chat
protocol:

    .warband xp             the module replies WARBAND_XP=<rate>
    .warband xp set <1-10>  applies the new rate immediately, then replies the same way

The slider sends the value when you release it; the -/+ buttons and the 1x / 3x / 5x / 10x presets
send on click. The status line shows what the server answered, or says so when the worldserver does
not answer at all. Changes are runtime-only: a worldserver restart or config reload returns the rate
to the configured default (3x).

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
    Warband.xml     layout: window chrome, tree pane, detail pane, the XP and gathering pages
    Bindings.xml    the WARBANDTOGGLE key binding entry, unbound by default

Adding a feature means adding a node to the Tree table in Warband.lua. Use status "live" only for
something that actually works, and "placeholder" for anything unfinished.

XP controls require a worldserver executable built with the Warband module and started after that
build. The panel is client-only: changing it needs no server build, just a client restart for the
addon files to be re-read.
