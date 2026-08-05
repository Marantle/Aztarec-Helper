# Changelog

## 1.3.0
- Since a 12.1 build the game hands out no coordinates inside the delve, so everything that read where you stand stopped working there. You record the route yourself now. During the Sermon press a section key or `/azt n`, `/azt e`, `/azt s`, `/azt w` for the quarter you run to, one press per wave, and the echoes play your recording back as before
- Four new key bindings, one per section. They replace the old capture key, which needed to read your position to know what to record. Set them in the game's Key Bindings screen or straight from the addon's settings, and the quarters on the room view are clickable during the memory game too, for mouse people
- The countdown window says "input wave 2" while a recording window is open, and a wave you skip shows as unknown through the echoes
- Answers land in order. Miss one and your next press catches it up, so two quick taps get you level again, and a wave still blank when the echoes start can be filled until its own echo plays. You cannot answer a wave that has not happened yet
- `/azt review` counts the waves you never answered, and says so plainly when one of them is what killed you
- The arrow works again during the echoes. It cannot see where you stand, so it walks the recorded order instead, showing the move out of the quarter the last wave left you in, in the same forward, left, right or stay terms as the spoken cues. It trusts the recording, so if you fell behind it points from where you should have been
- The arrow holds one color the whole way through, and you pick which in the settings panel. Gold, red, green, white, cyan or violet. The old red and green states are gone, because the encounter hides the moment a wave lands and a color that changes on a guess is worse than one that stays put
- The spoken cues follow the recorded route the same way, so they work again too. The settings panel has a volume slider beside the channel button, which is the game's own volume for that channel, so it shows the real level and moving it moves the sound options with it
- Talking Head is gone from the cue channel list. It was never a channel the game accepts, and anyone left on it moves to Master
- The view mode switch is gone. The room view sits still now, centered on the room with north up, since the moving views needed a readable position
- Each quarter on the room view wears the key that records it, so you can read the board instead of remembering which key is which. During the memory game the quarter under your cursor lights up, so a click lands where you meant it
- Click a section letter on the room view to show a world marker icon there instead, for players who drop marker flags in the quarters. A small arrow marks the letters as clickable while you are out of combat, and the menus step aside during the fight so they cannot swallow a click meant for recording. An icon you pick now shows everywhere the addon names that quarter, on the countdown, on the arrow and in the chat lines, not only on the board
- An Instructions button on the room view, in place of the old question mark in the corner. It opens a page explaining how the recording and the callouts work, and `/azt help` opens the same page
- Placement mode is called preview now, since holding the windows on screen is what it actually does. The button says whether it is on, and `/azt preview` is the command. `/azt place` still works
- A wipe clears the recorded route from the room view instead of leaving the dead run up. `/azt review` and `/azt replay` still remember it
- A notice explains the change once when you enter the delve
- The automatic recording mode, the move warning and the player marker on the room view are gone. All three needed to see where you stand, and none of them could survive the change. `/azt cap`, `/azt manual` and `/azt spin` went with them

## 1.2.1
- Direction cues, in beta for now: half a second before each echo wave lands the addon speaks where the safe quarter is from where you stand, forward, left, right or stay. The calls assume you are looking at the boss in the middle of the room. The options panel has the toggle (also `/azt cue`), test buttons for the four sounds and a choice of which sound channel they play through
- `/azt replay` speaks the calls too, so you can hear them between pulls while walking the route

## 1.1.1
- The arrow now shows your state by color: red while you still need to move, green once you stand in the safe quarter. While you are safe it points ahead at the next quarter so you can start the move early, and points down at you when there is nothing left to pre-move for
- Smaller download: the textures are compressed now and the addon list icon is sized to what the game actually draws
- Removed the quadrant grid rotation toggle. The default layout matches the fight, so the switch only existed to be pressed by accident

## 1.1.0
- Wave countdown in its own draggable window: how long until the current wave lands, both while recording and during the echoes
- MOVE warning turns the countdown red while you stand in a quadrant that is about to get hit
- Safe-spot arrow: a draggable quest-style arrow pointing at the called quadrant, with a green check while you stand in it, parked dimmed in the delve before the pull
- Every floating window has a padlock in its corner: locked windows can't be dragged and clicks pass through them
- The room view got an opts button, and its map and view mode controls moved into the settings panel
- The room view now defaults to being centered on you
- Spots recorded while you were crossing quadrants now carry a ? mark, so you know which calls to trust less
- `/azt review` shows what the last pull recorded and where you died
- `/azt replay` walks the last route through the room view on its real timings, for practice between pulls
- Settings panel (`/azt options`, also reachable from the addon compartment)
- `/azt place` shows the countdown and the arrow anywhere, for dragging them into place before you ever pull
- The display clears a couple of seconds after the last echo lands, instead of hanging around for ten
- The addon carries its own icon in the addon list now
- The room view can be hidden from the options panel, and stays hidden until you bring it back

## 1.0.1
- The room view header now shows the addon name instead of the zone, in a slightly bigger font

## 1.0.0
- Initial release
