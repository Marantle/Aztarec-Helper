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

local function buildWave()
    waveFrame = CreateFrame("Frame", "AztarecHelperWaveText", UIParent)
    waveFrame:SetSize(230, 34)
    AZT.MakeMovable(waveFrame, "wavePos", "TOP", 0, -180)

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
            msg = ("recording wave %d"):format(w.idx)
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
        local rC, gC, bC = 1, 1, 1
        local safeNow = AZT.safeNow
        if w.phase ~= "record" and AztarecHelperDB.moveWarn and safeNow then
            local quadNow = AZT.Safe and AZT.Safe.CurrentQuadrant()
            if quadNow == safeNow then
                rC, gC, bC = 0.4, 1, 0.5
            elseif quadNow then
                msg = "MOVE  " .. msg
                rC, gC, bC = 1, 0.25, 0.2
            end
        end
        local alpha = 1
        if remain and remain < FLASH_UNDER then
            alpha = 0.55 + 0.45 * math.abs(math.sin(GetTime() * FLASH_HZ * math.pi))
        end
        text:SetText(msg)
        text:SetTextColor(rC, gC, bC, alpha)
    end)
end

-- shows while there is wave state to render and hides the moment it clears
function AZT.WaveSync()
    local live = AZT.Wave and AZT.Wave.phase ~= nil
    local on = AztarecHelperDB.waveText and (live or AZT.placeMode)
    if not waveFrame then
        if not on then
            return
        end
        buildWave()
    end
    waveFrame:SetShown(on and true or false)
    if on and not live then
        -- placement sample in the widest state the current settings allow,
        -- so the chosen spot fits the real thing under pressure
        if AztarecHelperDB.moveWarn then
            waveFrame.text:SetText("MOVE  wave 2 of 5 - 1.8")
            waveFrame.text:SetTextColor(1, 0.25, 0.2, 1)
        else
            waveFrame.text:SetText("wave 2 of 5 - 1.8")
            waveFrame.text:SetTextColor(1, 1, 1, 1)
        end
    end
end
