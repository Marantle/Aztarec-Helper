-- Azta'rec Helper, copyright 2026 Rothirr, all rights reserved.
-- Read it if you want. Copying any of it into another addon is theft, and
-- running it through an AI tool first does not change that. The timings and
-- coordinates were measured by hand. Nothing here is licensed to anyone.

local _, AZT = ...

-- Settings panel. Canvas layout because the vertical list can't host the cue
-- audition row or the key binding column. Two columns of titled sections:
-- the windows, the sound and the route buttons on the left, keys, party and
-- the window locks on the right.

local panel = CreateFrame("Frame")
panel.name = "Azta'rec Helper"

-- The settings canvas hands us a fixed viewport and no scrolling of its own,
-- so the rows live on a page inside a scroll frame. Everything below anchors
-- to `page` and only the panel itself talks to the game.
local scroll = CreateFrame("ScrollFrame", nil, panel)
scroll:SetPoint("TOPLEFT")
scroll:SetPoint("BOTTOMRIGHT", -14, 0)

local page = CreateFrame("Frame", nil, scroll)
page:SetSize(600, 600)
scroll:SetScrollChild(page)

-- Re-read the state every time the panel opens. Rows register a refresher
-- and anything that changes what another row shows calls the lot.
local refreshers = {}
local function refreshAll()
    for _, fn in ipairs(refreshers) do
        fn()
    end
end
panel:SetScript("OnShow", refreshAll)

local title = page:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
title:SetPoint("TOPLEFT", 16, -16)
title:SetText("Azta'rec Helper")

-- the layout cursor. Rows stack downward from it and column() jumps it to
-- the top of the next column. down() keeps the deepest row of either column,
-- which is what the page has to be tall enough for
local cur = { x = 16, y = -50 }
local deepest = 0

local function down(dy)
    cur.y = cur.y - dy
    if -cur.y > deepest then
        deepest = -cur.y
    end
end

local function column(x)
    cur.x, cur.y = x, -50
end

local function section(name)
    down(6)
    local fs = page:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    fs:SetPoint("TOPLEFT", cur.x, cur.y)
    fs:SetText(name)
    down(22)
end

local function addTip(widget, tip)
    widget:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(tip, 1, 1, 1, 1, true)
        GameTooltip:Show()
    end)
    widget:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)
    return widget
end

local function addCheck(label, tip, get, set)
    local cb = CreateFrame("CheckButton", nil, page, "UICheckButtonTemplate")
    cb:SetSize(26, 26)
    cb:SetPoint("TOPLEFT", cur.x, cur.y)
    local fs = page:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    fs:SetPoint("LEFT", cb, "RIGHT", 4, 0)
    fs:SetText(label)
    cb:SetScript("OnClick", function(btn)
        set(btn:GetChecked() and true or false)
    end)
    addTip(cb, tip)
    refreshers[#refreshers + 1] = function()
        cb:SetChecked(get())
    end
    cb.label = fs
    down(30)
    return cb
end

local function addAction(label, handler, tip)
    local btn = CreateFrame("Button", nil, page, "UIPanelButtonTemplate")
    btn:SetSize(170, 22)
    btn:SetPoint("TOPLEFT", cur.x, cur.y)
    btn:SetText(label)
    btn:SetScript("OnClick", handler)
    if tip then
        addTip(btn, tip)
    end
    down(28)
    return btn
end

-- the panel's one text palette: gold when a thing is live, grey when not
local function tintLabel(fs, on)
    if on then
        fs:SetTextColor(1, 0.82, 0)
    else
        fs:SetTextColor(0.5, 0.5, 0.5)
    end
end

local function enableLook(w, on)
    w:SetEnabled(on)
    if w.label then
        tintLabel(w.label, on)
    end
end

-- A two state switch: a titled row with a word on each side of a small pill
-- and a knob that slides to the chosen one, the word not chosen in grey.
-- The pill and knob are svg files, which a 12.1 client draws straight from
-- disk, so the shapes are actually round. A 12.0 client has no
-- CreateVectorGraphics and gets flat squares with the same behavior.
local SWITCH_MEDIA = "Interface\\AddOns\\AztarecHelper\\Media\\"
local SWITCH_W, SWITCH_H, KNOB = 46, 22, 16

local function switchArt(parent, file, layer)
    if parent.CreateVectorGraphics then
        local v = parent:CreateVectorGraphics()
        v:SetSVG(SWITCH_MEDIA .. file)
        v:SetDrawLayer(layer)
        return v
    end
    local t = parent:CreateTexture(nil, layer)
    t:SetColorTexture(1, 1, 1)
    return t
end

local function addSwitch(name, leftText, rightText, tip, get, set)
    local f = CreateFrame("Button", nil, page)
    f:SetSize(300, 48)
    f:SetPoint("TOPLEFT", cur.x, cur.y)
    local head = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    head:SetPoint("TOPLEFT", 0, 0)
    head:SetText(name)
    f.label = head

    local track = switchArt(f, "switch-track.svg", "ARTWORK")
    track:SetSize(SWITCH_W, SWITCH_H)
    -- fixed spot rather than flowing after the left word, so stacked
    -- switches line their pills up
    track:SetPoint("TOPLEFT", 110, -22)
    track:SetVertexColor(0, 0, 0, 0.5)

    local leftFS = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    leftFS:SetPoint("RIGHT", track, "LEFT", -8, 0)
    leftFS:SetText(leftText)
    local rightFS = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    rightFS:SetPoint("LEFT", track, "RIGHT", 8, 0)
    rightFS:SetText(rightText)

    -- the knob rides a plain frame so the slide can be a real animation
    -- whichever art object sits inside
    local knob = CreateFrame("Frame", nil, f)
    knob:SetSize(KNOB, KNOB)
    local knobArt = switchArt(knob, "switch-knob.svg", "OVERLAY")
    knobArt:SetSize(KNOB, KNOB)
    knobArt:SetPoint("CENTER", knob)
    knobArt:SetVertexColor(1, 0.82, 0)

    local function paintWords(v, on)
        tintLabel(leftFS, on and not v)
        tintLabel(rightFS, on and v)
    end

    -- The slide moves the knob's anchor rather than playing a stock
    -- animation. The animation system shifts a frame by transform and the
    -- svg art does not ride transforms (the same hole as its missing
    -- rotation), so an animated knob frame drew its svg standing still.
    -- The OnUpdate only exists for the fifth of a second a slide runs.
    local LEFT_X = 3
    local RIGHT_X = SWITCH_W - KNOB - 3
    local SLIDE_T = 0.2

    local function place(x)
        knob:ClearAllPoints()
        knob:SetPoint("LEFT", track, "LEFT", x, 0)
    end

    local slideTo, slideFrom, slideStart
    local function onUpdate()
        local t = (GetTime() - slideStart) / SLIDE_T
        if t >= 1 then
            knob:SetScript("OnUpdate", nil)
            place(slideTo and RIGHT_X or LEFT_X)
            return
        end
        -- smoothstep, so the knob leaves and lands gently
        t = t * t * (3 - 2 * t)
        local to = slideTo and RIGHT_X or LEFT_X
        place(slideFrom + (to - slideFrom) * t)
    end

    local function apply(v, slide)
        paintWords(v, f:IsEnabled())
        if not slide then
            -- setters that refresh the whole panel land here mid slide, and
            -- a slide already heading the right way is left to finish
            -- rather than snapped home
            if knob:GetScript("OnUpdate") and slideTo == v then
                return
            end
            knob:SetScript("OnUpdate", nil)
            place(v and RIGHT_X or LEFT_X)
            return
        end
        -- start from wherever the knob is right now, so reversing a slide
        -- mid-run turns back instead of jumping to the far side first
        local kl, tl = knob:GetLeft(), track:GetLeft()
        slideFrom = (kl and tl) and (kl - tl) or (v and LEFT_X or RIGHT_X)
        slideTo = v
        slideStart = GetTime()
        knob:SetScript("OnUpdate", onUpdate)
    end

    f:SetScript("OnClick", function()
        local v = not get()
        -- slide first since the setter may refresh the panel on its way
        apply(v, true)
        set(v)
    end)

    -- the stock SetEnabled only stops the clicks, the greying is ours
    local setEnabled = f.SetEnabled
    function f:SetEnabled(on)
        setEnabled(self, on)
        if on then
            knobArt:SetVertexColor(1, 0.82, 0)
        else
            knobArt:SetVertexColor(0.5, 0.5, 0.5)
        end
        apply(get())
    end

    addTip(f, tip)
    refreshers[#refreshers + 1] = function()
        apply(get())
    end
    down(52)
    return f
end

-- follower mode owns these widgets: the route arrives as sealed calls with
-- no turn in them, so the arrow has nothing true to point at and the
-- recorded cues have nothing true to say. Their toggles lock off while
-- following is in effect and the stored settings come back untouched when
-- it stops. The voice for the calls themselves lives under Party instead
local followGated = {}
local function applyFollowGate()
    local locked = AZT.Follow and AZT.Follow.Suppress()
    for _, w in ipairs(followGated) do
        enableLook(w, not locked)
    end
end
refreshers[#refreshers + 1] = applyFollowGate

-- the widgets under the cues checkbox belong to it: voice pick, test
-- buttons, channel and volume all grey out while the cues are off, and
-- while following for the same reason the checkbox itself does. The list
-- fills as the rows build and the gate itself runs after the volume block,
-- where everything it touches exists.
local cueGated = {}
local function cuesLive()
    return AztarecHelperDB.cues and not (AZT.Follow and AZT.Follow.Suppress())
end

-- Key capture machinery for the quarter key rows, ahead of the layout so
-- the rows can use it. The capture lives on its own trap frame that only
-- exists while a listen runs, never on the rows. The settings canvas is
-- reparented by the client and its hide events are not trustworthy, a
-- lesson learned from a listener that survived the menu closing and kept
-- eating keys. On top of that a listen simply times out, so it cannot
-- outlive its moment no matter which events fire or fail to.
local MODS = { LSHIFT = true, RSHIFT = true, LCTRL = true, RCTRL = true, LALT = true, RALT = true }
local LISTEN_FOR = 10 -- seconds until a listen gives up on its own
local listening
local catcher
local listenTimer

local function keyText(cmd)
    local key = GetBindingKey(cmd)
    return key and GetBindingText(key) or "not bound"
end

local function stopListening()
    if listening then
        listening.btn:SetText(keyText(listening.cmd))
        listening = nil
    end
    if catcher then
        catcher:Hide()
    end
    if listenTimer then
        listenTimer:Cancel()
        listenTimer = nil
    end
end
panel:SetScript("OnHide", stopListening)

local function ensureCatcher()
    if catcher then
        return catcher
    end
    catcher = CreateFrame("Frame", nil, UIParent)
    catcher:SetFrameStrata("FULLSCREEN_DIALOG")
    catcher:EnableKeyboard(true)
    -- swallow the pressed key so it does not also do its normal job. Only
    -- reachable out of combat, the panel cannot open in lockdown
    catcher:SetPropagateKeyboardInput(false)
    catcher:Hide()
    catcher:SetScript("OnKeyDown", function(_, key)
        if not listening or key == "ESCAPE" then
            stopListening()
            return
        end
        if MODS[key] then
            return
        end
        local combo = (IsAltKeyDown() and "ALT-" or "")
            .. (IsControlKeyDown() and "CTRL-" or "")
            .. (IsShiftKeyDown() and "SHIFT-" or "")
            .. key
        local cmd = listening.cmd
        local old = GetBindingKey(cmd)
        if old then
            SetBinding(old)
        end
        SetBinding(combo, cmd)
        SaveBindings(GetCurrentBindingSet())
        stopListening()
    end)
    return catcher
end

local function startListening(btn, cmd)
    stopListening()
    listening = { btn = btn, cmd = cmd }
    btn:SetText("press a key")
    ensureCatcher():Show()
    listenTimer = C_Timer.NewTimer(LISTEN_FOR, stopListening)
end

-- a binding can change behind our back, the game's own Key Bindings screen
-- most of all, and combat must never inherit a live trap. Both drop any
-- pending listen, and a bindings change re-reads the rows
local bindWatch = CreateFrame("Frame")
bindWatch:RegisterEvent("UPDATE_BINDINGS")
bindWatch:RegisterEvent("PLAYER_REGEN_DISABLED")
bindWatch:SetScript("OnEvent", function(_, event)
    stopListening()
    if event == "UPDATE_BINDINGS" then
        -- the room view wears the keys, so it has to hear about this too
        if AZT.QuadClickSync then
            AZT.QuadClickSync()
        end
        if panel:IsShown() then
            refreshAll()
        end
    end
end)

local function addBindRow(label, cmd)
    local fs = page:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    fs:SetPoint("TOPLEFT", cur.x, cur.y - 5)
    fs:SetText(label)
    local btn = CreateFrame("Button", nil, page, "UIPanelButtonTemplate")
    btn:SetSize(120, 22)
    btn:SetPoint("TOPLEFT", cur.x + 130, cur.y)
    btn:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    btn:SetScript("OnClick", function(self, mouse)
        stopListening()
        if mouse == "RightButton" then
            local key = GetBindingKey(cmd)
            if key then
                SetBinding(key)
                SaveBindings(GetCurrentBindingSet())
            end
            self:SetText(keyText(cmd))
            return
        end
        startListening(self, cmd)
    end)
    addTip(btn, "Click, then press the key you want. Escape backs out and right click unbinds.")
    btn:SetScript("OnHide", function(self)
        if listening and listening.btn == self then
            stopListening()
        end
    end)
    refreshers[#refreshers + 1] = function()
        btn:SetText(keyText(cmd))
    end
    down(26)
end

-- Left column: everything the addon draws

section("Windows")

addCheck("Show the room view", "The main window with the top-down room. /azt room also shows and hides it.", function()
    return AztarecHelperDB.roomView
end, function(v)
    AZT.SetRoomShown(v)
end)

addSwitch(
    "Room view size",
    "Full",
    "Slim",
    "Set to Slim, the room view is cut down to the room itself, with the excess padding removed."
        .. " `/azt help` still opens the instructions.",
    function()
        return AztarecHelperDB.roomSlim
    end,
    function(v)
        AZT.SetRoomSlim(v)
    end
)

addCheck("Map art backdrop", "Draws Blizzard's own map tiles behind the room view.", function()
    return AztarecHelperDB.mapArt
end, function(v)
    if v ~= AztarecHelperDB.mapArt then
        AZT.ToggleMapArt()
    end
end)

addCheck("Wave countdown", "How long until the current wave hits, in a small window you can drag anywhere.", function()
    return AztarecHelperDB.waveText
end, function(v)
    AztarecHelperDB.waveText = v
    AZT.WaveSync()
end)

followGated[#followGated + 1] = addCheck(
    "Safe-spot arrow",
    "An arrow that shows the move for each echo, as if you were facing the boss in the middle,"
        .. " so up means straight through him and down means stay where you are."
        .. " It sits dimmed in the delve before the pull so you can drag it into place.",
    function()
        return AztarecHelperDB.arrow and not AztarecHelperDB.follow
    end,
    function(v)
        AztarecHelperDB.arrow = v
        AZT.ArrowSync()
    end
)

local colorBtn
colorBtn = addAction("", function()
    MenuUtil.CreateContextMenu(colorBtn, function(_, root)
        root:CreateTitle("Arrow color")
        for _, key in ipairs(AZT.ARROW_ORDER) do
            root:CreateButton(AZT.ARROW_COLORS[key].label, function()
                AztarecHelperDB.arrowColor = key
                colorBtn:SetText("Arrow: " .. AZT.ARROW_COLORS[key].label)
                AZT.ArrowSync()
            end)
        end
    end)
end, "The color the arrow draws in during the echoes. Gold leaves the artwork as it was painted.")
refreshers[#refreshers + 1] = function()
    colorBtn:SetText("Arrow: " .. AZT.ArrowColor().label)
end
followGated[#followGated + 1] = colorBtn

followGated[#followGated + 1] = addSwitch(
    "Arrow mode",
    "Relative",
    "Compass",
    "Relative is the move to make as if you were facing the boss, and the voice calls the"
        .. " same move. Compass points the way the room view points and carries that"
        .. " quarter's marker inside it. The spoken cues keep talking as if you face the boss either way,"
        .. " so turn them off below if the two readings mix badly for you.",
    function()
        return AztarecHelperDB.arrowCompass and not AztarecHelperDB.follow
    end,
    function(v)
        AztarecHelperDB.arrowCompass = v
        AZT.ArrowSync()
        -- the voice has no compass mode, so the first flip comes with a
        -- one-time heads-up about the mixed readings
        if v and AztarecHelperDB.cues and not AztarecHelperDB.compassCueAsked then
            AZT.ShowCompassCueAsk()
        end
    end
)

section("Spoken cues")

followGated[#followGated + 1] = addCheck(
    "Solo spoken cues",
    "Plays a short cue for each wave, forward, left, right or stay, off the route you recorded"
        .. " yourself. The cues assume you are facing the boss in the middle of the room."
        .. " Following someone else's calls has no turn in it to speak, so these lock off"
        .. " while you follow and the Party section has the voice for that.",
    function()
        return AztarecHelperDB.cues and not AztarecHelperDB.follow
    end,
    function(v)
        AztarecHelperDB.cues = v
        refreshAll()
    end
)

cueGated[#cueGated + 1] = addSwitch(
    "Cue voice",
    "Relative",
    "Markers",
    "Relative is the recorded voice calling the move to make, as if you face the boss."
        .. " Markers is the game's text to speech naming the safe quarter's marker instead,"
        .. " whatever each quarter wears, with no facing in it at all. The test buttons and"
        .. " the volume below follow the choice.",
    function()
        return AztarecHelperDB.cueMarks
    end,
    function(v)
        AztarecHelperDB.cueMarks = v
        refreshAll()
    end
)

-- Audition cluster, so the cue sounds can be judged without a pull. Laid
-- out the way the words mean: forward up top, left and right on their
-- sides, stay at the bottom. That same cross is the compass rose when the
-- cues name markers, so each button also carries a quarter and the labels
-- folow the voice the cues are set to.
local function cueBtn(dir, quad, x, y)
    local btn = CreateFrame("Button", nil, page, "UIPanelButtonTemplate")
    btn:SetSize(70, 22)
    btn:SetPoint("TOPLEFT", x, y)
    btn:SetScript("OnClick", function()
        if AztarecHelperDB.cueMarks then
            if not AZT.Speak(AZT.QuadWord(quad)) then
                AZT.chat("no text to speech voice on this machine")
            end
        else
            AZT.PlayCue(dir)
        end
    end)
    refreshers[#refreshers + 1] = function()
        if AztarecHelperDB.cueMarks then
            btn:SetText(AZT.QuadWord(quad))
        else
            btn:SetText(dir:sub(1, 1):upper() .. dir:sub(2))
        end
    end
    cueGated[#cueGated + 1] = btn
    return btn
end

local midX = cur.x + 84
local fwdBtn = cueBtn("forward", "N", midX, cur.y)
cueBtn("left", "W", cur.x + 10, cur.y - 24)
cueBtn("right", "E", midX + 74, cur.y - 24)
cueBtn("stay", "S", midX, cur.y - 48)
local cueLabel = page:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
cueLabel:SetPoint("CENTER", fwdBtn, "CENTER", 0, -24)
cueLabel:SetText("Test cues")
down(76)

local chanY = cur.y
local refreshVol

-- voice names arrive like "Microsoft David - English (United States)", far
-- too long for the button. The menu shows them whole.
local function shortVoice(name)
    return (name:gsub(" %- .*", ""):gsub("^Microsoft ", ""))
end

-- one button, two jobs: the sound channel for the recorded voice, the tts
-- voice for the marker one. Channels cycle like always, voices come as a
-- menu since a machine can have a dozen, and a pick says a word in the
-- voice so it can be judged right there.
local cueChanBtn
cueChanBtn = addAction("", function()
    if not AztarecHelperDB.cueMarks then
        cueChanBtn:SetText("Cues: " .. AZT.CycleCueChannel())
        refreshVol()
        return
    end
    MenuUtil.CreateContextMenu(cueChanBtn, function(_, root)
        root:CreateTitle("Marker voice")
        local voices = AZT.TtsVoices()
        if #voices == 0 then
            root:CreateButton("no text to speech voices found", function() end)
            return
        end
        for _, v in ipairs(voices) do
            root:CreateButton(v.name, function()
                AztarecHelperDB.ttsVoiceID = v.voiceID
                AZT.Speak(AZT.QuadWord("N"))
                refreshAll()
            end)
        end
    end)
end)
-- narrower than the stock action button so the slider clears the column
cueChanBtn:SetSize(150, 22)
addTip(
    cueChanBtn,
    "For the recorded voice, the sound channel the cues play through, and that channel's"
        .. " volume slider decides how loud they are. For the marker voice, which of the"
        .. " machine's text to speech voices does the talking. Picking one says a word in it."
)
refreshers[#refreshers + 1] = function()
    if AztarecHelperDB.cueMarks then
        local v = AZT.TtsVoice()
        cueChanBtn:SetText("Voice: " .. (v and shortVoice(v.name) or "none"))
    else
        cueChanBtn:SetText("Cues: " .. (AztarecHelperDB.cueChannel or "Master"))
    end
end

-- volume for the channel the cues play through. This is the game's own
-- slider for that channel, not a private one, so what it shows is what the
-- sound options show. Hand-built rather than OptionsSliderTemplate, which
-- Blizzard has reworked before.
local VOL_W = 130
local volSlider = CreateFrame("Slider", nil, page)
volSlider:SetSize(VOL_W, 16)
volSlider:SetPoint("TOPLEFT", 176, chanY - 3)
volSlider:SetOrientation("HORIZONTAL")
volSlider:SetMinMaxValues(0, 100)
volSlider:SetValueStep(1)
volSlider:SetObeyStepOnDrag(true)
volSlider:SetHitRectInsets(0, 0, -5, -5)

local track = volSlider:CreateTexture(nil, "BACKGROUND")
track:SetPoint("LEFT")
track:SetPoint("RIGHT")
track:SetHeight(6)
track:SetColorTexture(0.1, 0.1, 0.1, 0.9)

local fill = volSlider:CreateTexture(nil, "ARTWORK")
fill:SetPoint("LEFT", track, "LEFT", 0, 0)
fill:SetHeight(6)
fill:SetColorTexture(1, 0.82, 0, 1)

volSlider:SetThumbTexture("Interface/Buttons/UI-SliderBar-Button-Horizontal")
volSlider:GetThumbTexture():SetSize(14, 20)

-- under the slider rather than beside it, since beside would reach into
-- the right column and strand the number under someone else's section
local volText = page:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
volText:SetPoint("TOPLEFT", volSlider, "BOTTOMLEFT", 0, -4)

local function paintVol(v)
    fill:SetWidth(VOL_W * v / 100)
    volText:SetText(("%d%%"):format(v))
end

-- pushing a value into the slider fires OnValueChanged, which would write
-- straight back to the CVar. This says the change came from the game.
-- On the marker voice the slider is the tts volume instead, the addon's
-- own number, since tts does not ride the sound channels.
local reading
volSlider:SetScript("OnValueChanged", function(_, v)
    v = math.floor(v + 0.5)
    paintVol(v)
    if reading then
        return
    end
    if AztarecHelperDB.cueMarks then
        AztarecHelperDB.ttsVolume = v
        return
    end
    local cvar = AZT.CueChannelCVar()
    if cvar then
        C_CVar.SetCVar(cvar, tostring(v / 100))
    end
end)
addTip(
    volSlider,
    "How loud the cues are. For the recorded voice this is the game's own volume for the"
        .. " chosen channel, so moving it here moves the sound options too. For the marker"
        .. " voice it is the text to speech volume, which is the addon's own number."
)

refreshVol = function()
    local v
    if AztarecHelperDB.cueMarks then
        v = AztarecHelperDB.ttsVolume or 100
    else
        local cvar = AZT.CueChannelCVar()
        v = math.floor((tonumber(cvar and GetCVar(cvar)) or 1) * 100 + 0.5)
    end
    reading = true
    volSlider:SetValue(v)
    reading = false
    paintVol(v)
end
refreshers[#refreshers + 1] = refreshVol

-- the cue gate itself, down here where everything it greys exists. The
-- switch and the test buttons take the shared look, the rest have parts
-- enableLook cannot reach
local function applyCueGate()
    local on = cuesLive()
    for _, w in ipairs(cueGated) do
        enableLook(w, on)
    end
    tintLabel(cueLabel, on)
    tintLabel(volText, on)
    if on then
        fill:SetColorTexture(1, 0.82, 0, 1)
    else
        fill:SetColorTexture(0.5, 0.5, 0.5, 0.7)
    end
    cueChanBtn:SetEnabled(on)
    volSlider:SetEnabled(on)
    volSlider:GetThumbTexture():SetDesaturated(not on)
end
refreshers[#refreshers + 1] = applyCueGate

-- the sound options, a macro or anohter addon can move the same number, so
-- follow it while the panel is open
local volWatch = CreateFrame("Frame")
volWatch:RegisterEvent("CVAR_UPDATE")
volWatch:SetScript("OnEvent", function()
    if panel:IsShown() then
        refreshVol()
    end
end)

-- the route buttons live on the left, the party rows run the right column
-- deep enough as it is
section("Route")

addAction(
    "Practice the memory game",
    function()
        AZT.Safe.Practice()
    end,
    "A pretend sermon on the room view: seven waves, safe quarter green and the rest red."
        .. " Answer each one with your keys or clicks like a real pull, and the echoes that"
        .. " follow play back what you recorded. Click again to stop early."
)

addAction("Replay last pull", function()
    AZT.Safe.Replay()
end)

addAction("Review last pull", function()
    AZT.Safe.Review()
end)

addAction("Reset route", function()
    AZT.Safe.Reset()
    AZT.chat("recorded route cleared")
end)

-- Right column: the keys, what the party sees and the window locks

column(330)

-- quarter key rows, the same click-then-press flow as the game's own Key
-- Bindings screen. These write real bindings, so the Key Bindings screen
-- shows whatever is set here and the other way round. The command ids keep
-- their old MARK names, renaming those drops keybinds.
section("Quarter keybindings")

addBindRow("Answer north", "AZTARECHELPER_MARK_NORTH")
addBindRow("Answer east", "AZTARECHELPER_MARK_EAST")
addBindRow("Answer south", "AZTARECHELPER_MARK_SOUTH")
addBindRow("Answer west", "AZTARECHELPER_MARK_WEST")

addSwitch(
    "Answer keys",
    "Quarters",
    "Turns",
    "Set to Turns, your keys say the move you made rather than the quarter you ran to, read like the arrow:"
        .. " as if you face the boss in the middle. North is FORWARD, east is RIGHT and west"
        .. " is LEFT. The first wave still needs its compass direction, which is where the"
        .. " route starts. Marking and calling switch off, since a turn names no quarter.",
    function()
        return AztarecHelperDB.relativeTurns
    end,
    function(v)
        AZT.SetRelativeTurns(v)
        refreshAll()
    end
)

section("Party")

local markCb = addCheck(
    "Answer keys mark me",
    "Each press of a quarter key also puts that quarter's marker on you, through the game's own"
        .. " target marker system, so the party sees where you are heading even without the addon."
        .. " It only arms inside the delve. The wiring locks when a fight starts, so the sermon"
        .. " answers set markers as well as the echo moves.",
    function()
        return AztarecHelperDB.keysMark
    end,
    function(v)
        AztarecHelperDB.keysMark = v
        AZT.MarkKeysSync()
    end
)

local callCb = addCheck(
    "Call the route (leader)",
    "While you lead a party in the delve, each answer key press also says that quarter's marker"
        .. " number in party chat, through the game's own macro system, so followers with the addon"
        .. " see your route as you record it. The wiring locks when a fight starts, so a leadership"
        .. " change mid pull waits for the pull to end. One role at a time, turning this on turns"
        .. " following off.",
    function()
        return AztarecHelperDB.callRoute
    end,
    function(v)
        AZT.SetCallRoute(v)
        refreshAll()
    end
)

addSwitch(
    "Quarter names",
    "Markers",
    "Arrows",
    "Set to Arrows, the quarter markers become the four direction arrows everywhere the addon names a"
        .. " quarter, with the room read north up like the room view draws it. Your calls say"
        .. " Up, Right, Down or Left to match, so followers see arrows and their voice reads"
        .. " them out, and the words mean something to party members without the addon too."
        .. " The same choice sits in the quarter menus on the room view.",
    function()
        return AztarecHelperDB.callStyle == "arrows"
    end,
    function(v)
        AZT.SetCallStyle(v and "arrows" or "markers")
        -- the cue test buttons speak this language too
        refreshAll()
    end
)

local followCb = addCheck(
    "Follow the leader",
    "Shows the leader's route calls on a board of their own and on the wave countdown, timed by"
        .. " the boss like always. The addon can show the calls but never read them, so the arrow"
        .. " and the solo cues lock off while this is on and party chat during the sermon lands"
        .. " on the board. The"
        .. " board parks in the delve while this is on, so you can drag it into place. One role"
        .. " at a time, turning this on turns calling off.",
    function()
        return AztarecHelperDB.follow
    end,
    function(v)
        AZT.SetFollow(v)
        refreshAll()
    end
)

local voiceCb = addCheck(
    "Speak the leader's calls",
    "Reads each call out loud as its echo comes up, in the game's own text to speech voice."
        .. " It waits on the leader: they have to be calling directions rather than markers,"
        .. " since a voice reading a marker number out tells you nothing about where to run.",
    function()
        return AztarecHelperDB.callVoice
    end,
    function(v)
        AztarecHelperDB.callVoice = v
    end
)

-- the roles come from leadership, so the boxes track it: only a party
-- leader can turn calling on and a party leader cannot follow. A toggle
-- that is already on stays clickable, going off is always allowed
local function applyRoleGate()
    local leading = AZT.InPlayerParty() and UnitIsGroupLeader("player")
    local turns = AztarecHelperDB.relativeTurns
    enableLook(callCb, (leading or AztarecHelperDB.callRoute) and not turns)
    enableLook(markCb, not turns)
    enableLook(followCb, not leading or AztarecHelperDB.follow)
    -- the voice only ever speaks the leader's calls, so it rides the follow
    -- toggle rather than the live role
    enableLook(voiceCb, AztarecHelperDB.follow or AztarecHelperDB.callVoice)
end
refreshers[#refreshers + 1] = applyRoleGate

section("Locks")

-- the three windows share one lock story, so the rows come off a list
local LOCK_TIP =
    "No dragging, and clicks pass through it. Hover its corner and click the padlock to unlock, or untick this."
for _, w in ipairs({
    { key = "arrow", label = "Lock the arrow" },
    { key = "wave", label = "Lock the countdown" },
    { key = "follow", label = "Lock the route board" },
    {
        key = "room",
        label = "Lock the room view",
        tip = "No dragging, and clicks pass through it. The Opts and Instructions buttons and the padlock keep working.",
    },
}) do
    addCheck(w.label, w.tip or LOCK_TIP, function()
        return AZT.GetWindowLock(w.key)
    end, function(v)
        AZT.SetWindowLock(w.key, v)
    end)
end

down(24)
addAction("Updates", function()
    AZT.ShowNotice()
end)

local ver = page:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
ver:SetPoint("TOPLEFT", cur.x, cur.y - 4)
ver:SetTextColor(0.7, 0.7, 0.7)
ver:SetText("v" .. AZT.VERSION .. ", /azt for the command list")

-- the page is as tall as the deeper of the two columns, plus room for the
-- version line hanging off the bottom of it
page:SetHeight(deepest + 40)

-- A plain position indicator rather than a grab handle, since the wheel is
-- what moves the page. It hides itself when everything already fits.
local barTrack = panel:CreateTexture(nil, "ARTWORK")
barTrack:SetPoint("TOPRIGHT", -6, -8)
barTrack:SetPoint("BOTTOMRIGHT", -6, 8)
barTrack:SetWidth(4)
barTrack:SetColorTexture(1, 1, 1, 0.07)

local barThumb = panel:CreateTexture(nil, "OVERLAY")
barThumb:SetWidth(4)
barThumb:SetColorTexture(1, 0.82, 0, 0.45)

local function paintBar()
    local range = scroll:GetVerticalScrollRange()
    local view = scroll:GetHeight()
    if range < 1 or view < 1 then
        barTrack:Hide()
        barThumb:Hide()
        return
    end
    barTrack:Show()
    barThumb:Show()
    local barH = barTrack:GetHeight()
    local thumb = math.max(24, barH * view / (view + range))
    barThumb:ClearAllPoints()
    barThumb:SetHeight(thumb)
    barThumb:SetPoint("TOP", barTrack, "TOP", 0, -(barH - thumb) * scroll:GetVerticalScroll() / range)
end

local WHEEL_STEP = 40
scroll:EnableMouseWheel(true)
scroll:SetScript("OnMouseWheel", function(self, delta)
    local range = self:GetVerticalScrollRange()
    local v = self:GetVerticalScroll() - delta * WHEEL_STEP
    self:SetVerticalScroll(math.min(math.max(v, 0), range))
    paintBar()
end)

-- the canvas sizes us on the first open and on any UI scale change, and the
-- page has to be as wide as the viewport or the right column falls off it
scroll:SetScript("OnSizeChanged", function(_, w)
    page:SetWidth(w)
    paintBar()
end)
refreshers[#refreshers + 1] = paintBar

local category = Settings.RegisterCanvasLayoutCategory(panel, panel.name)
Settings.RegisterAddOnCategory(category)

function AZT.OpenOptions()
    if InCombatLockdown() then
        AZT.chat("the settings panel can't open in combat")
        return
    end
    Settings.OpenToCategory(category:GetID())
end

-- lead can change hands while the panel is open, Follow.Sync pokes this so
-- the role gates keep up
function AZT.RefreshOptions()
    if panel:IsShown() then
        refreshAll()
    end
end
