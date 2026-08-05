-- Azta'rec Helper, copyright 2026 Rothirr, all rights reserved.
-- Read it if you want. Copying any of it into another addon is theft, and
-- running it through an AI tool first does not change that. The timings and
-- coordinates were measured by hand. Nothing here is licensed to anyone.

local _, AZT = ...

-- Settings panel. Canvas layout because the vertical list can't host the cue
-- audition row or the key binding column.

local panel = CreateFrame("Frame")
panel.name = "Azta'rec Helper"

-- re-read the state every time the panel opens
local refreshers = {}
panel:SetScript("OnShow", function()
    for _, fn in ipairs(refreshers) do
        fn()
    end
end)

local y = -16

local title = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
title:SetPoint("TOPLEFT", 16, y)
title:SetText("Azta'rec Helper")
y = y - 34

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
    local cb = CreateFrame("CheckButton", nil, panel, "UICheckButtonTemplate")
    cb:SetSize(26, 26)
    cb:SetPoint("TOPLEFT", 16, y)
    local fs = panel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    fs:SetPoint("LEFT", cb, "RIGHT", 4, 0)
    fs:SetText(label)
    cb:SetScript("OnClick", function(btn)
        set(btn:GetChecked() and true or false)
    end)
    addTip(cb, tip)
    refreshers[#refreshers + 1] = function()
        cb:SetChecked(get())
    end
    y = y - 30
end

local function addAction(label, handler, tip)
    local btn = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    btn:SetSize(170, 22)
    btn:SetPoint("TOPLEFT", 16, y)
    btn:SetText(label)
    btn:SetScript("OnClick", handler)
    if tip then
        addTip(btn, tip)
    end
    y = y - 28
    return btn
end

addCheck("Show the room view", "The main window with the top-down room. /azt room also shows and hides it.", function()
    return AztarecHelperDB.roomView
end, function(v)
    AZT.SetRoomShown(v)
end)

addCheck("Wave countdown", "How long until the current wave hits, in a small window you can drag anywhere.", function()
    return AztarecHelperDB.waveText
end, function(v)
    AztarecHelperDB.waveText = v
    AZT.WaveSync()
end)

addCheck(
    "Safe-spot arrow",
    "An arrow that shows the move for each echo, red while the move is due and green"
        .. " pointing ahead once the wave is about to land."
        .. " It sits dimmed in the delve before the pull so you can drag it into place.",
    function()
        return AztarecHelperDB.arrow
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

addCheck("Map art backdrop", "Draws Blizzard's own map tiles behind the room view.", function()
    return AztarecHelperDB.mapArt
end, function(v)
    if v ~= AztarecHelperDB.mapArt then
        AZT.ToggleMapArt()
    end
end)

addCheck(
    "Direction cues (beta)",
    "Plays a short call for each wave, forward, left, right or stay."
        .. " The calls assume you are facing the boss in the middle of the room.",
    function()
        return AztarecHelperDB.cues
    end,
    function(v)
        AztarecHelperDB.cues = v
    end
)

-- audition row, so the cue sounds can be judged without a pull
local cueX = 26
for _, dir in ipairs({ "forward", "left", "right", "stay" }) do
    local btn = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    btn:SetSize(74, 22)
    btn:SetPoint("TOPLEFT", cueX, y)
    btn:SetText(dir:sub(1, 1):upper() .. dir:sub(2))
    btn:SetScript("OnClick", function()
        AZT.PlayCue(dir)
    end)
    cueX = cueX + 78
end
y = y - 28

local chanY = y
local refreshVol
local cueChanBtn
cueChanBtn = addAction("", function()
    cueChanBtn:SetText("Cues: " .. AZT.CycleCueChannel())
    refreshVol()
end)
addTip(
    cueChanBtn,
    "The sound channel the calls play through. That channel's volume slider decides how loud they are."
        .. " Master stays audible even with effects turned down."
)
refreshers[#refreshers + 1] = function()
    cueChanBtn:SetText("Cues: " .. (AztarecHelperDB.cueChannel or "Master"))
end

-- volume for the channel the calls play through. This is the game's own
-- slider for that channel, not a private one, so what it shows is what the
-- sound options show. Hand-built rather than OptionsSliderTemplate, which
-- Blizzard has reworked before.
local VOL_W = 130
local volSlider = CreateFrame("Slider", nil, panel)
volSlider:SetSize(VOL_W, 16)
volSlider:SetPoint("TOPLEFT", 196, chanY - 3)
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

local volText = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
volText:SetPoint("LEFT", volSlider, "RIGHT", 10, 0)

local function paintVol(v)
    fill:SetWidth(VOL_W * v / 100)
    volText:SetText(("%d%%"):format(v))
end

-- pushing a value into the slider fires OnValueChanged, which would write
-- straight back to the CVar. This says the change came from the game.
local reading
volSlider:SetScript("OnValueChanged", function(_, v)
    v = math.floor(v + 0.5)
    paintVol(v)
    if reading then
        return
    end
    local cvar = AZT.CueChannelCVar()
    if cvar then
        C_CVar.SetCVar(cvar, tostring(v / 100))
    end
end)
addTip(
    volSlider,
    "How loud the calls are. This is the game's own volume for that channel,"
        .. " so moving it here moves it in the sound options too."
)

refreshVol = function()
    local cvar = AZT.CueChannelCVar()
    local v = math.floor((tonumber(cvar and GetCVar(cvar)) or 1) * 100 + 0.5)
    reading = true
    volSlider:SetValue(v)
    reading = false
    paintVol(v)
end
refreshers[#refreshers + 1] = refreshVol

-- the sound options, a macro or anohter addon can move the same number, so
-- follow it while the panel is open
local volWatch = CreateFrame("Frame")
volWatch:RegisterEvent("CVAR_UPDATE")
volWatch:SetScript("OnEvent", function()
    if panel:IsShown() then
        refreshVol()
    end
end)

addCheck(
    "Lock the arrow",
    "No dragging, and clicks pass through it. Hover its corner and click the padlock to unlock, or untick this.",
    function()
        return AZT.GetWindowLock("arrow")
    end,
    function(v)
        AZT.SetWindowLock("arrow", v)
    end
)

addCheck(
    "Lock the countdown",
    "No dragging, and clicks pass through it. Hover its corner and click the padlock to unlock, or untick this.",
    function()
        return AZT.GetWindowLock("wave")
    end,
    function(v)
        AZT.SetWindowLock("wave", v)
    end
)

addCheck(
    "Lock the room view",
    "No dragging, and clicks pass through it. The Opts and Instructions buttons and the padlock keep working.",
    function()
        return AZT.GetWindowLock("room")
    end,
    function(v)
        AZT.SetWindowLock("room", v)
    end
)

y = y - 8

local previewBtn
previewBtn = addAction(
    "Preview windows",
    function()
        AZT.SetPlaceMode(not AZT.placeMode)
        previewBtn:SetText(AZT.placeMode and "Hide preview" or "Preview windows")
    end,
    "Holds the countdown and the arrow on screen out of combat so you can drag them where you want."
        .. " They normally only appear while the boss is doing something."
)
refreshers[#refreshers + 1] = function()
    previewBtn:SetText(AZT.placeMode and "Hide preview" or "Preview windows")
end

addAction("Replay last pull", function()
    AZT.Safe.Replay()
end)

addAction("Review last pull", function()
    AZT.Safe.Review()
end)

addAction("Reset sequence", function()
    AZT.Safe.Reset()
    AZT.chat("safe-spot sequence cleared")
end)

addAction("Updates", function()
    AZT.ShowNotice()
end)

-- section key rows in a right hand column, the same click-then-press flow
-- as the game's own Key Bindings screen. These write real bindings, so the
-- Key Bindings screen shows whatever is set here and the other way round.
local BINDS = {
    { "Mark north safe", "AZTARECHELPER_MARK_NORTH" },
    { "Mark east safe", "AZTARECHELPER_MARK_EAST" },
    { "Mark south safe", "AZTARECHELPER_MARK_SOUTH" },
    { "Mark west safe", "AZTARECHELPER_MARK_WEST" },
}
local MODS = { LSHIFT = true, RSHIFT = true, LCTRL = true, RCTRL = true, LALT = true, RALT = true }
local listening

local function keyText(cmd)
    local key = GetBindingKey(cmd)
    return key and GetBindingText(key) or "not bound"
end

-- the key capture lives on its own trap frame that only exists while a
-- listen runs, never on the rows. The settings canvas is reparented by the
-- client and its hide events are not trustworthy, a lesson learned from a
-- listener that survived the menu closing and kept eating keys. On top of
-- that a listen simply times out, so it cannot outlive its moment no
-- matter which events fire or fail to.
local LISTEN_FOR = 10 -- seconds until a listen gives up on its own
local catcher
local listenTimer

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
            for _, fn in ipairs(refreshers) do
                fn()
            end
        end
    end
end)

local by = -50
local bindHead = panel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
bindHead:SetPoint("TOPLEFT", 330, by)
bindHead:SetText("Section keys")
by = by - 24

local function addBindRow(label, cmd)
    local fs = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    fs:SetPoint("TOPLEFT", 330, by - 5)
    fs:SetText(label)
    local btn = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    btn:SetSize(120, 22)
    btn:SetPoint("TOPLEFT", 460, by)
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
    by = by - 26
end

for _, b in ipairs(BINDS) do
    addBindRow(b[1], b[2])
end

y = y - 8

local ver = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
ver:SetPoint("TOPLEFT", 16, y)
ver:SetTextColor(0.7, 0.7, 0.7)
ver:SetText("v" .. AZT.VERSION .. ", /azt for the command list")

local category = Settings.RegisterCanvasLayoutCategory(panel, panel.name)
Settings.RegisterAddOnCategory(category)

function AZT.OpenOptions()
    if InCombatLockdown() then
        AZT.chat("the settings panel can't open in combat")
        return
    end
    Settings.OpenToCategory(category:GetID())
end
