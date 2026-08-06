-- Azta'rec Helper, copyright 2026 Rothirr, all rights reserved.
-- Read it if you want. Copying any of it into another addon is theft, and
-- running it through an AI tool first does not change that. The timings and
-- coordinates were measured by hand. Nothing here is licensed to anyone.

local _, AZT = ...

-- The wave countdown, in its own little window so it can sit where the
-- player actually looks during the fight.

local waveFrame
local FLASH_UNDER = 1.5 -- countdown starts pulsing this close to a hit
local FLASH_HZ = 2.0
local COUNT_CAP = 9 -- a countdown longer than this is noise

local BOX_H = 34

local function buildWave()
    waveFrame = CreateFrame("Frame", "AztarecHelperWaveText", UIParent)
    waveFrame:SetSize(230, BOX_H)
    AZT.MakeMovable(waveFrame, "wavePos", "TOP", 0, -180 - BOX_H * 1.5)

    local bg = waveFrame:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetColorTexture(0, 0, 0, 0.25)
    local text = waveFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    text:SetPoint("CENTER")
    waveFrame.text = text
    AZT.AttachLock(waveFrame, "wave")
    waveFrame:Hide()

    local elapsed = 0
    waveFrame:SetScript("OnUpdate", function(_, dt)
        elapsed = elapsed + dt
        if elapsed < 0.05 then
            return
        end
        elapsed = 0
        local w = AZT.Wave
        if not w or not w.phase then
            return
        end
        local msg
        if w.phase == "record" then
            msg = ("input wave %d"):format(w.idx)
        elseif w.total then
            msg = ("wave %d of %d"):format(w.idx, w.total)
        else
            msg = ("wave %d"):format(w.idx)
        end
        local remain
        if w.at then
            local okR, r = pcall(function()
                return w.at - GetTime()
            end)
            if okR and type(r) == "number" and r > 0 and r <= COUNT_CAP then
                remain = r
            end
        end
        if remain then
            msg = msg .. (" - %.1f"):format(remain)
        end
        -- during the echoes the box leads with where to be and trails with
        -- where next, in whatever the player picked for those quarters. The
        -- next one is smaller since it is not the one being counted down.
        local safeNow, nextNow = AZT.safeNow, AZT.nextNow
        if w.phase ~= "record" and safeNow then
            msg = AZT.QuadName(safeNow, 20) .. "  " .. msg
            if nextNow then
                msg = msg .. "  >  " .. AZT.QuadName(nextNow, 16)
            end
        end
        local alpha = 1
        if remain and remain < FLASH_UNDER then
            alpha = 0.55 + 0.45 * math.abs(math.sin(GetTime() * FLASH_HZ * math.pi))
        end
        text:SetText(msg)
        text:SetTextColor(1, 1, 1, alpha)
    end)
end

-- Same visibility as the arrow: parked around the delve out of combat so it
-- can be dragged into place, live while the memory game runs, and out of the
-- way in combat when it has nothing to say.
function AZT.WaveSync()
    local live = AZT.Wave and AZT.Wave.phase ~= nil
    local fighting = AZT.inCombat or InCombatLockdown() or (AZT.Safe and AZT.Safe.IsArmed and AZT.Safe.IsArmed())
    local idleParked = AZT.InDelve() and not fighting
    local on = AztarecHelperDB.waveText and (live or idleParked or AZT.placeMode)
    if not waveFrame then
        if not on then
            return
        end
        buildWave()
    end
    waveFrame:SetShown(on and true or false)
    if on and not live then
        -- named while it is only sitting there, and a sample countdown while
        -- placing so the window is the width it will really be
        waveFrame.text:SetText(AZT.placeMode and "N  wave 2 of 5 - 1.8  >  E" or "wave countdown")
        waveFrame.text:SetTextColor(1, 1, 1, 0.5)
    end
end
