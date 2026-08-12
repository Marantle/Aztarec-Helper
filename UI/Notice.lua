-- Azta'rec Helper, copyright 2026 Rothirr, all rights reserved.
-- Read it if you want. Copying any of it into another addon is theft, and
-- running it through an AI tool first does not change that. The timings and
-- coordinates were measured by hand. Nothing here is licensed to anyone.

local _, AZT = ...

-- The reading box. One frame, two things to say: the notice about the 12.1
-- position blackout, which shows itself once on the first delve entry, and
-- the instructions, which wait behind the room view's button.

local box

local NERF_TITLE = "What changed in 12.1"
local NERF = "Since a 12.1 build the game hands out no coordinates inside this delve. "
    .. "Nothing can read where you stand in there, this addon included, so automatic "
    .. "recording and the dot that showed you on the map are out.\n\n"
    .. "Recording is manual now. During the Sermon, press a quarter key or click the quarter "
    .. "on the room view for the quarter you run to, one press per wave, and the "
    .. "echoes play your recording back. Waves you skip show as unknown.\n\n"
    .. "The Instructions button on the room view has the rest.\n\n"
    .. "Also, sorry for shouting in your ear with the new spoken cues, I wanted to use "
    .. "real voice instead of TTS for some personality. Whichever sound channel you point "
    .. "the cues at has a volume slider in the settings, and /azt cue shuts me up for good.\n\n"
    .. "Check back on August 19th. This will still be the best addon for this fight.\n\n"
    .. "Fabled Let Me Solo Him: Azta'rec wants him dead on Tier ?? with nobody else in "
    .. "your party, inside the first week of Midnight Season 2. The memory game is the "
    .. "part that ends those runs, and remembering it is the one thing this addon does."

local INSTR_TITLE = "How to use it"
local INSTR = "Azta'rec slams three quarters of the room at once during Sermon of Ula'tek "
    .. "and leaves one safe, a few times in a row with the ground showing you where. "
    .. "Then he repeats the same order with nothing showing, and that is the part this "
    .. "addon remembers with you.\n\n"
    .. "While the ground still shows the safe quarter, tell the addon where you went. "
    .. "Press that quarter's key, or click the quarter on the room view. One answer per "
    .. "wave. The countdown window says which wave it is waiting for and how long you "
    .. "have, because the boss's own channel gives away the timing.\n\n"
    .. "Answers land in order, so a late one still counts. Miss the third wave and your "
    .. "next press takes the third slot, which means two quick taps get you level again. "
    .. "You cannot answer a wave that has not happened yet, and a wave left blank when "
    .. "the echoes begin can still be filled right up until its own echo plays. Anything "
    .. "you never answer stays unknown.\n\n"
    .. "When the echoes start, the room view lights the quarter you are due in green and the "
    .. "one after it yellow. The arrow shows the move to make from where the last wave "
    .. "left you and the voice calls it out loud.\n\n"
    .. "The arrow and the voice both talk as if you are looking at the boss in the middle "
    .. "of the room. Forward means straight through him. Left and right are your left and "
    .. "right from there, and stay means the route keeps you where you are. Turn "
    .. "your back on him and they will be backwards, so keep him in front of you.\n\n"
    .. "Your four keys live in the settings panel and in the game's Key Bindings screen "
    .. "under AddOns. Each quarter on the room view shows its own key. The quarters wear "
    .. "markers rather than compass letters. drop the matching world markers in the room. Click a marker out of combat "
    .. "to change it. Between pulls, /azt replay walks "
    .. "the last route again at "
    .. "its real speed and /azt review says what it recorded."

local function build()
    box = CreateFrame("Frame", "AztarecHelperNotice", UIParent, "BackdropTemplate")
    box:SetSize(480, 100)
    box:SetPoint("CENTER", 0, 140)
    -- above the settings panel, since the Updates button opens it from there
    box:SetFrameStrata("FULLSCREEN_DIALOG")
    box:SetBackdrop({
        bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true,
        tileSize = 16,
        edgeSize = 12,
        insets = { left = 3, right = 3, top = 3, bottom = 3 },
    })
    box:SetBackdropColor(0, 0, 0, 0.85)
    box:EnableMouse(true)
    box:SetMovable(true)
    box:RegisterForDrag("LeftButton")
    box:SetScript("OnDragStart", box.StartMoving)
    box:SetScript("OnDragStop", box.StopMovingOrSizing)

    local title = box:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOP", 0, -12)
    box.title = title

    local body = box:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    body:SetPoint("TOPLEFT", 18, -38)
    body:SetPoint("TOPRIGHT", -18, -38)
    body:SetJustifyH("LEFT")
    body:SetSpacing(2)
    box.body = body

    -- one button for reading, two when the box is asking something
    local right = CreateFrame("Button", nil, box, "UIPanelButtonTemplate")
    right:SetSize(150, 22)
    right:SetPoint("BOTTOM", 0, 12)
    box.right = right

    local left = CreateFrame("Button", nil, box, "UIPanelButtonTemplate")
    left:SetSize(150, 22)
    left:SetPoint("RIGHT", right, "LEFT", -8, 0)
    box.left = left

    table.insert(UISpecialFrames, "AztarecHelperNotice")
end

-- text with one dismiss button, or a question with a choice on either side
local function show(title, text, ask)
    if not box then
        build()
    end
    box.title:SetText(title)
    box.body:SetText(text)
    box:SetHeight(38 + box.body:GetStringHeight() + 48)
    box.left:SetShown(ask and true or false)
    box.right:ClearAllPoints()
    if ask then
        box.left:SetText(ask.leftText)
        box.left:SetScript("OnClick", function()
            box:Hide()
            ask.left()
        end)
        -- shifted right so the pair sits centred with the left button
        box.right:SetPoint("BOTTOM", 79, 12)
        box.right:SetText(ask.rightText)
        box.right:SetScript("OnClick", function()
            box:Hide()
            ask.right()
        end)
    else
        box.right:SetPoint("BOTTOM", 0, 12)
        box.right:SetText("Got it")
        box.right:SetScript("OnClick", function()
            box:Hide()
        end)
    end
    box:Show()
end

-- the options panel's Updates button reopens the notice any time
function AZT.ShowNotice()
    show(NERF_TITLE, NERF)
end

function AZT.ShowInstructions()
    show(INSTR_TITLE, INSTR)
end

-- The compass arrow changes what the arrow points at, but the voice has no
-- compass mode, it keeps talking as if you face the boss. Said once when
-- the compass is first ticked, with the choice in hand, instead of
-- silently mixing the two readings. Anyone who ran the compass before this
-- ask existed is grandfathered by the bootstrap and keeps their cue toggle
-- as it stands.
local COMPASS_TITLE = "Compass arrow and the spoken cues"
local COMPASS_CUES = "With compass arrow, the arrow points the way the room view does "
    .. "but the voices still talk as if you are facing the boss. "
    .. "Disable Solo spoken cues in options if you want the arrow to be the only cue. "

function AZT.ShowCompassCueAsk()
    AztarecHelperDB.compassCueAsked = true
    show(COMPASS_TITLE, COMPASS_CUES, {
        leftText = "Turn cues off",
        left = function()
            AztarecHelperDB.cues = false
            AZT.chat("solo spoken cues: OFF")
        end,
        rightText = "Keep the cues",
        right = function() end,
    })
end

-- Party play, offered when the role calls for it: the leader hears about
-- calling, everyone else about following. Core/Follow.lua decides when to
-- show these, once per stint in a role, and the options keep both
-- changeable at any time.
local CALL_TITLE = "Call the route for your party?"
local CALL_TEXT = "You lead this group. With calling on, your answer keys also name each"
    .. " quarter in party chat as you record, by its marker number or as a direction if you"
    .. " switch that on, and party members running the addon see your route on the boss's"
    .. " timing. The keys work"
    .. " as before otherwise. One ask for the group: keep party chat quiet during the"
    .. " fight, since stray lines land on the followers' boards as garbage. Declining"
    .. " keeps the semi automatic mode, where you record and answer for yourself only."
    .. " Either way you can change your mind under Party in the options."

function AZT.ShowCallAsk()
    show(CALL_TITLE, CALL_TEXT, {
        leftText = "Call the route",
        left = function()
            AZT.SetCallRoute(true)
            AZT.chat("route calling: ON while you lead")
        end,
        rightText = "Stay semi automatic",
        right = function() end,
    })
end

local FOLLOW_TITLE = "Follow the leader's calls?"
local FOLLOW_TEXT = "Someone else leads this group. With following on, their route calls show"
    .. " on a board of their own and on the wave countdown, timed by the boss like always."
    .. " A leader who calls directions rather than markers gets read out loud as well, which"
    .. " is its own tickbox under Party. The addon can show the calls but never read them,"
    .. " so there is no arrow while you follow,"
    .. " and any party chat during the sermon lands on the board. Declining keeps the semi"
    .. " automatic mode, where you record and answer for yourself like when solo. Either way"
    .. " you can change your mind under Party in the options."

function AZT.ShowFollowAsk()
    show(FOLLOW_TITLE, FOLLOW_TEXT, {
        leftText = "Follow the calls",
        left = function()
            AZT.SetFollow(true)
            AZT.chat("following the leader: ON")
        end,
        rightText = "Stay semi automatic",
        right = function() end,
    })
end

local ef = CreateFrame("Frame")
ef:RegisterEvent("PLAYER_ENTERING_WORLD")
ef:RegisterEvent("ZONE_CHANGED_NEW_AREA")
ef:SetScript("OnEvent", function()
    if AztarecHelperDB.nerfNoticeSeen or not AZT.InDelve() then
        return
    end
    AztarecHelperDB.nerfNoticeSeen = true
    AZT.ShowNotice()
end)
