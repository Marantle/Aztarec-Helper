# Changelog

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
