# Azta'rec Helper

Automatically shows you where to stand during the Echo of Ula'tek phase, no manual clicking or macros required!

Consider this a beta for now. Azta'rec arrives with Midnight Season 2 (12.1), which is still weeks away on the PTR.

Azta'rec's memory game. During **Sermon of Ula'tek** he repeatedly slams three quarters of the room at once with Waves of Venom, and ground indicators show you where. Then he repeats the exact same sequence as **Echo of Ula'tek**, without the indicators.

This addon remembers it for you. While the indicators are up it records which quarter you stood in for each wave. When the echoes start, a top-down view of the boss room shows the full route, an arrow points at the safe quarter, and a countdown tells you how long you have to get there.

![The room view in action](https://rothirr.wordpress.com/wp-content/uploads/2026/08/aztarechelper2.0.webp)

## Features

*   Automatic recording, no keypresses needed during the fight. Dodge the visible waves like you normally would and the route is captured.
*   Safe-spot arrow: red and pointing at the safe quarter while you need to move, green once you are standing right. While you are safe it points ahead at the next quarter, so you can start moving the moment the wave resolves. Grey while the boss is still channeling, gone when there is nothing to do.
*   Wave countdown in its own small window: which wave is up and how long until it lands, read from the boss's own cast. It turns red with a MOVE prefix while you stand in a doomed quarter and green once you are safe.
*   Top-down room radar with the actual in-game map as the backdrop (toggleable). Green is the current safe quarter, yellow is the next one, red is everything else. The view centers on you by default, and it can rotate with your facing or hold north up instead.
*   Honest recording: a wave captured while you were sprinting between quarters gets a ? mark, so you know which calls to trust a little less.
*   `/azt review` shows what the last pull recorded and, if you died, which echo got you and where safe was. `/azt replay` runs the route through the display on its real timings, so you can practice reading it between pulls.
*   Handles the longer sequences on higher tiers, where the pattern grows with every intermission.
*   Manual mode for people who want full control: turn off the automatic recording and mark each safe quarter yourself with the capture key. The same key also works during automatic recording, as an override for a single wave if the addon guessed wrong (caught mid-run between quarters at the wrong moment, for example).
*   Every window drags where you want it and remembers the spot. A small padlock in the corner locks a window in place and lets clicks pass through it. `/azt place` shows everything anywhere, so you can arrange your layout without pulling the boss first.
*   A proper settings panel. Open it with `/azt options`, from the Opts button on the room view, or from the addon compartment by the minimap.

*A note on lineage: if you have seen another addon do this, the idea started here. The recording and the radar were measured and built in mid-July 2026 and went public in this addon on July 25, the file list on this page is the proof. The other addon for this fight adopted the approach in early August, with credit to this one in its source.*

## Commands

*   `/azt room` toggles the room view (it auto-shows in the delve)
*   `/azt manual` switches between automatic and manual recording
*   `/azt cap` captures your current quarter (bindable in Key Bindings, macroable)
*   `/azt replay` replays the last recorded route, for practice
*   `/azt review` shows what the last pull recorded and where you died
*   `/azt place` shows the countdown and arrow anywhere, for dragging into place
*   `/azt reset` clears the recorded route
*   `/azt options` opens the settings panel
*   `/azt map` and `/azt spin` still work if you prefer commands, though the options panel covers both now

## Notes

The addon only reads your own position and the boss's cast events, so it works within the encounter restrictions Blizzard added in Midnight. It cannot show you a route it never saw: if you die mid-recording, the next Sermon starts a fresh one, and `/azt review` will tell you what went wrong on the last attempt.
