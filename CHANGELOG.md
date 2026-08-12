# Changelog

## 1.5.0
- The four direction arrows are a quarter language of their own, picked from the same menu as the markers on the room view or from the settings. Take it and every quarter reads as its arrow instead of a shape, on the room view, the countdown and the arrow itself. It is all four or none, since a follower has no way to tell one call's language from another's. Marking yourself still uses the quarter's marker, a target icon being the only thing the game will put on a player
- A leader on the arrows calls the route in words, Up, Right, Down and Left, with the room read north up like the room view draws it. Followers see arrows on their board rather than marker icons, and the words mean something to party members without the addon as well. The choice travels with the leader's icon sync, so every board knows what it is drawing before the pull
- Speak the leader's calls, a new option for followers: each call read out loud as its echo comes up, in the game's own text to speech voice. It waits on the leader calling directions, since a voice reading a marker number out tells you nothing about where to run. The old recorded cues are Solo spoken cues now, so the two voices are never mistaken for each other, and they keep to your own recorded route like they always did
- Fresh installs start on star north, square east, triangle south and circle west, four shapes that stay apart at a glance. Anyone who already has the addon keeps the markers they picked
- The settings panel scrolls now, so a long column cannot run off the bottom of the canvas. The route buttons moved under the sound settings on the left and the Updates button sits on the right, which gives the party rows the room they needed

## 1.4.0
- Party play. When you lead a party in the delve, the new Call the route option makes your answer keys also call each quarter's marker number in party chat, one press answering, marking and calling together. The calls go through the game's own macro system, so nothing ever sends on its own. Only the leader can call, and the addon offers the role when you take the lead
- Follow the leader is the other side: the leader's calls show as marker icons on a route board and on the wave countdown, timed off the boss like always. In the fight chat is sealed to addons, so the calls can be shown but never read. That is why the arrow and the spoken cues lock off while following, with your own settings returning untouched when you stop, and why party chat during the fight should stay quiet, since stray lines land on the board as garbage
- The route board collects the calls while the leader records, then walks the echoes with the current call drawn big and pinned at the board's left edge while the rest trails smaller to the right. Draggable and lockable like the other windows, and parked it shows a stand-in marker where the live call will sit. It parks in the delve whenever following is on, no party needed, so it can be placed ahead of the group forming
- The leader's quarter icons sync to the party between fights, so every member's room view, countdown and board speak the leader's icon language. Display only, everyone's own picks stay saved
- `/azt call` and `/azt follow` toggle the two modes from chat. The modes are one or the other, switching one on switches the other off, and the roles come from leadership: call refuses anyone who is not leading, follow refuses the leader, and the settings grey the box your role rules out. A follow toggle left on while you lead sits inert and comes back when the lead moves on
- Outside the delve the addon now does nothing at all: no events, no listeners, everything asleep until you zone in. `/azt anywhere` overrides the detection and treats where you stand as the boss room, kept for the day Blizzard renumbers the delve and the addon stops recognizing it
- Answer keys mark me, a new option: each press of a quarter key also puts that quarter's marker on you, through the game's own target marker system, so your party can follow your moves with no addon of their own. It uses whatever icon the quarter wears on the room view and only arms inside the delve. The wiring locks when a fight starts, so the sermon answers set markers as well as the echo moves, note this is not automatic, just something to help you mark yourself for your friends
- The settings panel grew into sections and a second column. The windows and the spoken cues sit on the left while the quarter keys, the party options, the window locks and the route buttons sit on the right
- The spoken cues are out of beta. They have behaved since 1.3.6, so the label was only scaring people off
- When a cue cannot play, the message now names the sound channel it tried, since a channel disabled in the sound options is the usual reason. And switching channels warns anew instead of staying quiet for the rest of the session

## 1.3.8
- The quarter marker menus work on a locked room view now, out of combat. The lock still blocks dragging and still lets fight clicks pass through, it just stopped taking the icon menus down with it

## 1.3.7
- The quarter you answer flashes for a moment, keyed or clicked, so you know the press landed without taking your eyes off the fight
- Answer presses during the pull only count in the Sermon and the echoes now. A stray press in the dead moments used to sneak an extra wave onto the route and confuse the countdown. Sketching a route by hand between pulls stays as it was

## 1.3.6
- The compass arrow no longer silences the spoken cues. 1.3.4 muted them in that mode while the cue toggle still said ON, which came back in reports as broken audio. The cues now keep playing, spoken as if you face the boss like always
- In their place a question box explains the pairing the first time you tick the compass arrow: the arrow reads the map while the voice reads you, and you choose whether the cues stay on or go. Anyone already running the compass skips the question and keeps whatever their cue toggle already says
- The Preview windows button in the settings plays the memory game now: three pretend waves run through the room view, the countdown and the arrow on the real cadence, calls included. The old static preview and `/azt preview` are gone, watching the pretend run is how you drag the windows into place now

## 1.3.5
- Naming conventions unified, like the the main window is now referred to as Room View everywhere, and marking a safe zone is now referred to as Answer

## 1.3.4
- Compass arrow in the settings, for anyone who does not keep the boss in front of them. The arrow points the way the room view points and carries that quarter's marker below it, so it tells you the compass direction to run in. The spoken cues stay quiet in that mode, since forward and left only mean something in the old relative mode
- The quarter's marker under the arrow draws bigger, in both modes
- The parked arrow before the pull says which reading you are on, relative or compass
- One name per thing now, everywhere. The window is the room view, not the board or the radar, the slices are quarters, what you record is the route and you answer a wave rather than mark or input it. The keybinds read Answer north and so on, and keys you already bound carry over
- Direction cues go by spoken cues now, same feature, same `/azt cue`

## 1.3.3
- The quarters now by default select markers. triangle north, square east, cross south, circle west, which is `/wm 2`, `/wm 1`, `/wm 4` and `/wm 6` for the matching flares
- Click a marker out of combat to change it or put the letter back
- The map art behind the room view starts off now
- The room view says "keybinds not set" while any of the four section keys is still unbound
- Slim room view in the settings cuts the window down to the room itself, dropping the title, the Instructions button and the compass letters
- Tidier default window positions on a fresh install

## 1.3.2
- `/azt replay` calls each step as it comes up. It used to hold the call until the step was nearly over, which put the voice about three seconds later than a real pull and made it sound a step behind
- The arrow points at your feet through the Sermon, so the moment it swings to the first call you know the echoes have started

## 1.3.1
- The arrow holds one color the whole way through an echo phase, and you pick which one in the settings panel. Gold, red, green, white, cyan or violet, with gold leaving the artwork as it was painted
- The red and green states are gone. Green was meant for the moment a wave lands, and the encounter hides that moment, so it almost never arrived and the arrow sat red regardless
- The parked arrow out of combat wears your color too, dimmed, so you can see what you are picking while you pick it
- The arrow stops pointing when an echo runs well past the spacing the ones before it set, instead of holding a call that is not coming
- The instructions no longer promise the voice half a second of warning. That timing needs the boss's cast bar, which the encounter keeps hidden, so the call lands when the echo starts instead

## 1.3.0
- Since a 12.1 build the game hands out no coordinates inside the delve, so everything that read where you stand stopped working there. You record the route yourself now. During the Sermon press a section key or `/azt n`, `/azt e`, `/azt s`, `/azt w` for the quarter you run to, one press per wave, and the echoes play your recording back as before
- Four new key bindings, one per section. They replace the old capture key, which needed to read your position to know what to record. Set them in the game's Key Bindings screen or straight from the addon's settings, and the quarters on the room view are clickable during the memory game too, for mouse people
- The countdown window says "input wave 2" while a recording window is open, and a wave you skip shows as unknown through the echoes
- Answers land in order. Miss one and your next press catches it up, so two quick taps get you level again, and a wave still blank when the echoes start can be filled until its own echo plays. You cannot answer a wave that has not happened yet
- `/azt review` counts the waves you never answered, and says so plainly when one of them is what killed you
- The arrow works again during the echoes. It cannot see where you stand, so it walks the recorded order instead, showing the move out of the quarter the last wave left you in, in the same forward, left, right or stay terms as the spoken cues. It trusts the recording, so if you fell behind it points from where you should have been
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
