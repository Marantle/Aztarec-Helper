-- Azta'rec Helper, copyright 2026 Rothirr, all rights reserved.
-- Read it if you want. Copying any of it into another addon is theft, and
-- running it through an AI tool first does not change that. The timings and
-- coordinates were measured by hand. Nothing here is licensed to anyone.

local _, AZT = ...

-- Spoken direction calls for the echoes. The boss stands in the room centre
-- and the player is looking at him, so from any quarter the safe one is
-- ahead, left, right or the one they are already in. No facing read needed.

local MEDIA = "Interface\\AddOns\\AztarecHelper\\Media\\"
local SOUNDS = {
    forward = MEDIA .. "forward.mp3",
    left = MEDIA .. "left.mp3",
    right = MEDIA .. "right.mp3",
    stay = MEDIA .. "stay.mp3",
}

local CHANNELS = { "Master", "SFX", "Music", "Ambience", "Dialog", "Talking Head" }

local warned = false

-- shared by the live calls and the test buttons in the options panel.
-- Master by default so the calls stay audible with sound efects turned down
function AZT.PlayCue(turn)
    local ok, willPlay = pcall(PlaySoundFile, SOUNDS[turn], AztarecHelperDB.cueChannel or "Master")
    if not (ok and willPlay) and not warned then
        warned = true
        AZT.chat("cue sound failed to play: " .. SOUNDS[turn])
    end
end

-- next channel in the ring, for the cycle button in the options
function AZT.CycleCueChannel()
    local idx = 1
    for i, c in ipairs(CHANNELS) do
        if c == AztarecHelperDB.cueChannel then
            idx = i
        end
    end
    AztarecHelperDB.cueChannel = CHANNELS[idx % #CHANNELS + 1]
    return AztarecHelperDB.cueChannel
end

local CUE_LEAD = 0.5 -- how long before the wave lands the word plays

local function speak(safeQuad)
    -- no position read means silence, never a wrong call
    local turn = AZT.Safe.TurnFromTo(AZT.Safe.CurrentQuadrant(), safeQuad)
    if not turn then
        return
    end
    AZT.PlayCue(turn)
end

-- called at cast start with the wave's landing time. The word waits until
-- CUE_LEAD before the hit, so it arrives when moving is due and reads the
-- player's quarter where they stand by then. With no readable landing time
-- it speaks at once rather than never.
function AZT.Cue(safeQuad, hitAt)
    if not AztarecHelperDB.cues then
        return
    end
    local delay
    local ok, d = pcall(function()
        return hitAt - GetTime() - CUE_LEAD
    end)
    if ok and type(d) == "number" and d > 0.1 and d < 10 then
        delay = d
    end
    if not delay then
        speak(safeQuad)
        return
    end
    C_Timer.NewTimer(delay, function()
        -- a reset or a stopped replay clears the wave, stay quiet then
        if AZT.Wave.at == hitAt then
            speak(safeQuad)
        end
    end)
end
