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
    .. "on the room view for the quarter you run to, one press per wave, and the echo "
    .. "callouts play your recording back. Waves you skip show as unknown.\n\n"
    .. "The Instructions button on the room view has the rest.\n\n"
    .. "Also, sorry for shouting in your ear with the new spoken cues, I wanted to use "
    .. "real voice instead of TTS for some personality. Whichever sound channel you point "
    .. "the calls at has a volume slider in the settings, and /azt cue shuts me up for good.\n\n"
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

    local btn = CreateFrame("Button", nil, box, "UIPanelButtonTemplate")
    btn:SetSize(90, 22)
    btn:SetPoint("BOTTOM", 0, 12)
    btn:SetText("Got it")
    btn:SetScript("OnClick", function()
        box:Hide()
    end)

    table.insert(UISpecialFrames, "AztarecHelperNotice")
end

local function show(title, text)
    if not box then
        build()
    end
    box.title:SetText(title)
    box.body:SetText(text)
    box:SetHeight(38 + box.body:GetStringHeight() + 48)
    box:Show()
end

-- the options panel's Updates button reopens the notice any time
function AZT.ShowNotice()
    show(NERF_TITLE, NERF)
end

function AZT.ShowInstructions()
    show(INSTR_TITLE, INSTR)
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
