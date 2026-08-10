-- Azta'rec Helper, copyright 2026 Rothirr, all rights reserved.
-- Read it if you want. Copying any of it into another addon is theft, and
-- running it through an AI tool first does not change that. The timings and
-- coordinates were measured by hand. Nothing here is licensed to anyone.

local _, AZT = ...

-- The answer keys doubling as the party signal: each press also puts the
-- pressed quarter's marker on the player, so the group can follow the caller
-- without running the addon themselves. SetRaidTarget from addon code is silently
-- ignored these days and a mark has to travel Blizzard's secure macro path,
-- so every key is rerouted onto a hidden secure button whose canned macro
-- targets the player, drops the marker and targets back. The capture press
-- still happens through PostClick and nothing about answering changes.
--
-- Secure wiring is frozen during combat and can only move between pulls.
-- That is why the option arms for the whole fight and sermon presses mark
-- too. A sermon/echo split inside one pull cannot exist.

local QUAD_CMDS = {
    N = "AZTARECHELPER_MARK_NORTH",
    E = "AZTARECHELPER_MARK_EAST",
    S = "AZTARECHELPER_MARK_SOUTH",
    W = "AZTARECHELPER_MARK_WEST",
}
local owner -- the override bindings hang here, one clear drops them all
local buttons = {}
local armed = false

local function button(q)
    local btn = buttons[q]
    if not btn then
        btn = CreateFrame("Button", "AztarecHelperMarkKey" .. q, nil, "SecureActionButtonTemplate")
        btn:RegisterForClicks("AnyDown")
        btn:SetScript("PostClick", function()
            AZT.Safe.CaptureQuadrant(q)
        end)
        buttons[q] = btn
    end
    return btn
end

local function arm()
    owner = owner or CreateFrame("Frame")
    ClearOverrideBindings(owner)
    local me = UnitName("player")
    for q, cmd in pairs(QUAD_CMDS) do
        local keys = { GetBindingKey(cmd) }
        if #keys > 0 then
            local btn = button(q)
            -- a quarter shown as its plain letter still wears its seeded marker
            local icon = (AztarecHelperDB.quadIcons and AztarecHelperDB.quadIcons[q]) or AZT.MARK_SEED[q]
            btn:SetAttribute("type", "macro")
            btn:SetAttribute("macrotext", ("/targetexact %s\n/tm %d\n/targetlasttarget"):format(me, icon))
            for _, key in ipairs(keys) do
                SetOverrideBindingClick(owner, true, key, btn:GetName())
            end
        end
    end
    armed = true
end

local function disarm()
    if owner then
        ClearOverrideBindings(owner)
    end
    armed = false
end

local ev = CreateFrame("Frame")

-- (re)wire to match the option, the zone and the current binds. A sync that
-- lands in combat listens for the regen edge and runs there, since the
-- wiring cannot move untill then anyway
function AZT.MarkKeysSync()
    if not AztarecHelperDB then
        return -- UPDATE_BINDINGS fires at login before saved variables load
    end
    if InCombatLockdown() then
        ev:RegisterEvent("PLAYER_REGEN_ENABLED")
        return
    end
    ev:UnregisterEvent("PLAYER_REGEN_ENABLED")
    if AztarecHelperDB.keysMark and AZT.InDelve() then
        arm()
    elseif armed then
        disarm()
    end
end

ev:RegisterEvent("PLAYER_ENTERING_WORLD")
ev:RegisterEvent("ZONE_CHANGED_NEW_AREA")
ev:RegisterEvent("UPDATE_BINDINGS")
ev:SetScript("OnEvent", function()
    AZT.MarkKeysSync()
end)
