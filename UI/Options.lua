-- Azta'rec Helper, copyright 2026 Rothirr, all rights reserved.
-- Read it if you want. Copying any of it into another addon is theft, and
-- running it through an AI tool first does not change that. The timings and
-- coordinates were measured by hand. Nothing here is licensed to anyone.

local _, AZT = ...

-- Settings panel. Canvas layout because the vertical list can't host the view
-- mode cycle button

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
    cb:SetScript("OnEnter", function(btn)
        GameTooltip:SetOwner(btn, "ANCHOR_RIGHT")
        GameTooltip:SetText(tip, 1, 1, 1, 1, true)
        GameTooltip:Show()
    end)
    cb:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)
    refreshers[#refreshers + 1] = function()
        cb:SetChecked(get())
    end
    y = y - 30
end

local function addAction(label, handler)
    local btn = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    btn:SetSize(170, 22)
    btn:SetPoint("TOPLEFT", 16, y)
    btn:SetText(label)
    btn:SetScript("OnClick", handler)
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
    "An arrow that points at the called safe quadrant until you get there."
        .. " It sits dimmed in the delve before the pull so you can drag it into place.",
    function()
        return AztarecHelperDB.arrow
    end,
    function(v)
        AztarecHelperDB.arrow = v
        AZT.ArrowSync()
    end
)

addCheck(
    "Move warning",
    "Turns the countdown red while you are standing in a quadrant the wave is about to hit.",
    function()
        return AztarecHelperDB.moveWarn
    end,
    function(v)
        AztarecHelperDB.moveWarn = v
        AZT.WaveSync()
    end
)

addCheck("Map art backdrop", "Draws Blizzard's own map tiles behind the room view.", function()
    return AztarecHelperDB.mapArt
end, function(v)
    if v ~= AztarecHelperDB.mapArt then
        AZT.ToggleMapArt()
    end
end)

addCheck(
    "Manual recording",
    "Record spots with the capture key only, no automatic sampling. Ticking this clears the current sequence.",
    function()
        return AztarecHelperDB.manualMode
    end,
    function(v)
        AztarecHelperDB.manualMode = v
        AZT.Safe.Reset()
    end
)

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

local cueChanBtn
cueChanBtn = addAction("", function()
    cueChanBtn:SetText("Cues: " .. AZT.CycleCueChannel())
end)
cueChanBtn:SetScript("OnEnter", function(btn)
    GameTooltip:SetOwner(btn, "ANCHOR_RIGHT")
    GameTooltip:SetText(
        "The sound channel the calls play through. That channel's volume slider decides how loud they are."
            .. " Master stays audible even with effects turned down.",
        1,
        1,
        1,
        1,
        true
    )
    GameTooltip:Show()
end)
cueChanBtn:SetScript("OnLeave", function()
    GameTooltip:Hide()
end)
refreshers[#refreshers + 1] = function()
    cueChanBtn:SetText("Cues: " .. (AztarecHelperDB.cueChannel or "Master"))
end

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
    "No dragging, and clicks pass through it. The Opts button and the padlock keep working.",
    function()
        return AZT.GetWindowLock("room")
    end,
    function(v)
        AZT.SetWindowLock("room", v)
    end
)

y = y - 8

local viewBtn
viewBtn = addAction("", function()
    AZT.CycleViewMode(true)
    viewBtn:SetText("View: " .. AZT.ViewModeLabel())
end)
refreshers[#refreshers + 1] = function()
    viewBtn:SetText("View: " .. AZT.ViewModeLabel())
end

addAction("Place windows", function()
    AZT.SetPlaceMode(not AZT.placeMode)
end)

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
