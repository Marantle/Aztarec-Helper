# note! the automatic mode no longer works as Blizzard limited addons more

Blizzard did what I expected and nerfed addons capabilities and player position is now hidden, thanks for respecting the original Azta'rec automation, but this addon is still a beast and will get better!

# Azta'rec Helper

Azta'rec Helper is back for Midnight Season 2, and there is more coming on August 19th.

Azta'rec's memory game. During **Sermon of Ula'tek** he repeatedly slams three quarters of the room at once with Waves of Venom, and ground indicators show you where. Then he repeats the exact same sequence as **Echo of Ula'tek**, without the indicators.

This addon remembers it with you, and it is a manual thing now. While the indicators are still up you tell it where you went, one key or one click per wave, and it holds the whole order for you.

Then the echoes start and the addon takes over. The room view lights the quarter you are due in green and the one after it yellow. The arrow shows the move to make and a voice calls the same move out loud, forward, left, right or stay. Neither of them can see where you are standing, so both work from the order you recorded. Both of them speak as if you are looking at the boss in the middle of the room, so forward means straight through him, and turning your back on him reads everything backwards.

Going for **Fabled Let Me Solo Him: Azta'rec**? That one wants him dead on Tier ?? with nobody else in your party, inside the first week of Midnight Season 2. Tier ?? runs up to eight waves in a phase, which is where solo attempts usually end, and remembering that sequence is the one thing this addon does.

## Half the automation is gone

Recording used to be automatic. Since a 12.1 build the game hands out no coordinates inside the delve, for every addon alike, so this one cannot see where you stand. That took the automatic recording with it, along with the dot that put you on the map and the warning when you stood in a quarter about to get hit.

Everything that reads the boss still works. It knows when the Sermon starts, how many waves are coming, when each one lands and when every echo fires, all of it measured by hand on the PTR over about thirteen deaths. You supply the one thing it lost, one key per wave, and the rest runs the way it always did.

![The room view in action](https://rothirr.wordpress.com/wp-content/uploads/2026/08/nerfedhelper.webp)

## Features

*   Wave-timed recording. The addon reads the rhythm of the waves from the boss's own channel, so it listens for your answers. One press per wave, from four bindable keys or the `/azt n`, `/azt e`, `/azt s` and `/azt w` commands for macros. You can also click the quarter on the room view while the memory game runs. Answers land in order, so a missed one is caught up by your next press, and a wave still blank when the echoes start can be filled right until its own echo plays.
*   The arrow gives you the move for each echo, read as if you were facing the boss in the middle. Up is straight through him, left and right are your own and down means stay where you are. Turn your back on him and it reads backwards.
*   Or switch it to the compass arrow, which points the way the room view's green quarter points and carries the quarter's own marker inside it, for players who do not keep the boss in front of them. The spoken cues turn off in that mode, since forward and left belong to the other one.
*   Spoken cues for anyone who would rather listen than look. As each echo starts a voice says forward, left, right or stay, read the same way as the relative arrow points, so keep the boss in front of you when you are going by ear. `/azt cue` toggles them, and the settings panel has a test button for each sound.
*   Wave countdown in its own small window. It shows which wave is up and which quarter comes after this one, and it counts the seconds down while the boss's own timing is readable.
*   Top-down room view with the actual in-game map behind it, which you can turn off. Green is the current safe quarter, yellow is the next one and red is everything else. The view holds north up.
*   The quarters are marked with world markers. From north clockwise, triangle, square, cross and circle, so `/wm 2`, `/wm 1`, `/wm 4` and `/wm 6` drop the matching markers in the room. The markers name the quarters everywhere, on the room view, the countdown, the arrow and in chat, and clicking one out of combat changes it.
*   An Instructions button on the room view explains the whole thing in one page. Slim room view in the settings minimizes the room window.
*   A wave you never answered shows as unknown, on the room view and through its echo.
*   `/azt review` shows what the last pull recorded and, if you died, which echo got you. `/azt replay` runs the route through the display on its real timings, so you can practice reading it between pulls.
*   Handles the longer sequences on higher tiers, where the pattern grows with every intermission.
*   Every window drags where you want it and remembers the spot. A small padlock in the corner locks a window in place and lets clicks pass through it. `/azt preview` holds the countdown and the arrow on screen, so you can arrange your layout without pulling the boss first.
*   A settings panel with the quarter keys bindable in it. Open it with `/azt options`, from the Options button on the room view or from the addon compartment by the minimap.

*A note on lineage: if you have seen another addon do this, the idea started here. The recording and the room view were measured and built in mid-July 2026 and went public in this addon on July 25. The file list on this page is the proof. The other addon for this fight adopted the approach in early August, with credit to this one in its source.*

## Commands

*   `/azt room` toggles the room view (it auto-shows in the delve)
*   `/azt n`, `/azt e`, `/azt s`, `/azt w` record that quarter for the earliest wave you have not answered (bindable in Key Bindings, macroable)
*   `/azt replay` replays the last recorded route, for practice
*   `/azt review` shows what the last pull recorded and where you died
*   `/azt cue` toggles the spoken cues
*   `/azt help` opens the instructions
*   `/azt preview` holds the countdown and arrow on screen, for dragging into place
*   `/azt reset` clears the recorded route
*   `/azt options` opens the settings panel
*   `/azt map` toggles the map art backdrop

## Notes

The addon reads the boss's cast events and your answers, nothing the encounter restrictions forbid. It cannot show a route it never got, so a wave you never answer stays unknown, though a missed one can be caught up later in the same pull. If you die mid-recording the next Sermon starts a fresh one. The room view clears when the pull ends, and `/azt review` will tell you what went wrong on the last attempt.
