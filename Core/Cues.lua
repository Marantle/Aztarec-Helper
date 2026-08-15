-- Azta'rec Helper, copyright 2026 Rothirr, all rights reserved.
-- Read it if you want. Copying any of it into another addon is theft, and
-- running it through an AI tool first does not change that. The timings and
-- coordinates were measured by hand. Nothing here is licensed to anyone.

local _, AZT = ...

-- Spoken cues for the echoes. The boss stands in the room centre
-- and the player is looking at him from the quarter the previous wave put
-- them in, so the safe one is ahead, left, right or the one they are already
-- in. The turn comes from the recorded route, nothing reads the player.
-- On the marker setting the voice names the safe quarter's marker through
-- text to speech instead, no facing assumption in it at all.

local MEDIA = "Interface\\AddOns\\AztarecHelper\\Media\\"
local SOUNDS = {
    forward = MEDIA .. "forward.mp3",
    left = MEDIA .. "left.mp3",
    right = MEDIA .. "right.mp3",
    stay = MEDIA .. "stay.mp3",
}

-- the five channels PlaySoundFile actually accepts, each with the game's own
-- volume CVar behind it so the addon's slider and the sound options move the
-- same number
local CHANNELS = { "Master", "SFX", "Music", "Ambience", "Dialog" }
local VOL_CVAR = {
    Master = "Sound_MasterVolume",
    SFX = "Sound_SFXVolume",
    Music = "Sound_MusicVolume",
    Ambience = "Sound_AmbienceVolume",
    Dialog = "Sound_DialogVolume",
}

function AZT.CueChannelCVar()
    return VOL_CVAR[AztarecHelperDB.cueChannel or "Master"]
end

local warned = false

-- shared by the live cues and the test buttons in the options panel.
-- Master by default so the cues stay audible with sound efects turned down
function AZT.PlayCue(turn)
    local chan = AztarecHelperDB.cueChannel or "Master"
    local ok, willPlay = pcall(PlaySoundFile, SOUNDS[turn], chan)
    if not (ok and willPlay) and not warned then
        warned = true
        AZT.chat(
            ("cue '%s' failed to play on %s - check that channel is enabled in the sound options"):format(turn, chan)
        )
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
    -- a fresh channel deserves a fresh warning if it fails too
    warned = false
    return AztarecHelperDB.cueChannel
end

-- names for the marker each quarter can wear, raid target indexing
local MARK_NAMES = { "Star", "Circle", "Diamond", "Triangle", "Moon", "Square", "Cross", "Skull" }

function AZT.TtsVoices()
    return C_VoiceChat.GetTtsVoices() or {}
end

-- The voice the player picked if the machine still has it, else whatever
-- comes first. Resolved per call, the list can change under a session and
-- the calls are far too rare to be worth a cache going stale over. The
-- second return says whether that is really the pick or the fallback.
function AZT.TtsVoice()
    local voices = AZT.TtsVoices()
    for i, v in ipairs(voices) do
        if v.voiceID == AztarecHelperDB.ttsVoiceID then
            return v, i
        end
    end
    return voices[1], nil
end

-- Everything the addon says out loud goes through here. Says whether it
-- spoke, and "novoice" against "failed" tells a machine with no voice
-- apart from a sink that refused the call.
function AZT.Speak(text)
    local voice, pickedAt = AZT.TtsVoice()
    -- every value here is the addon's own, safe to format in a fight
    AZT.Log(
        ("SPEAK want=%s pickedAt=%s voices=%d"):format(
            tostring(AztarecHelperDB.ttsVoiceID),
            tostring(pickedAt),
            #AZT.TtsVoices()
        )
    )
    if not voice then
        return false, "novoice"
    end
    -- normal rate, no overlap so a late word cuts the one before off rather
    -- than talk over it. The pcall is for the sink itself, a build can take
    -- secret values away from it like the textures
    if not pcall(C_VoiceChat.SpeakText, voice.voiceID, text, 0, AztarecHelperDB.ttsVolume or 100, false) then
        return false, "failed"
    end
    return true
end

-- What a quarter is called out loud when the cues name quarters: the marker
-- it wears, read the same way the boards read it, or its direction word
-- when the room reads in arrows.
function AZT.QuadWord(q)
    if AZT.Follow and AZT.Follow.Arrows() then
        return AZT.QUAD_DIR[q]
    end
    return MARK_NAMES[AZT.QuadIcon(q) or AZT.MARK_SEED[q]]
end

local CUE_LEAD = 0.5 -- how long before the wave lands the word plays

local marksWarned = false

local function speak(safeQuad, fromQuad)
    if AztarecHelperDB.cueMarks then
        local word = AZT.QuadWord(safeQuad)
        if word and AZT.Speak(word) then
            return
        end
        if word and not marksWarned then
            marksWarned = true
            AZT.chat("the marker names cannot be spoken on this machine - using the turn words instead")
        end
        -- fall through to the turn voice rather than go quiet
    end
    -- an unknown step in the route means silence, never a wrong cue
    local turn = AZT.Safe.TurnFromTo(fromQuad, safeQuad)
    if not turn then
        return
    end
    AZT.PlayCue(turn)
end

-- called at cast start with the wave's landing time and the quarter the
-- previous wave left the player in. The word waits until CUE_LEAD before the
-- hit, so it arrives when moving is due. With no readable landing time it
-- speaks at once rather than never.
function AZT.Cue(safeQuad, hitAt, fromQuad)
    -- following locks the voice off, since the calls carry no turn to speak
    if not AztarecHelperDB.cues or (AZT.Follow and AZT.Follow.Suppress()) then
        return
    end
    local delay
    if hitAt then
        local ok, d = pcall(function()
            return hitAt - GetTime() - CUE_LEAD
        end)
        if ok and type(d) == "number" and d > 0.1 and d < 10 then
            delay = d
        end
    end
    if not delay then
        speak(safeQuad, fromQuad)
        return
    end
    C_Timer.NewTimer(delay, function()
        -- a reset or a stopped replay clears the wave, stay quiet then
        if AZT.Wave.at == hitAt then
            speak(safeQuad, fromQuad)
        end
    end)
end
