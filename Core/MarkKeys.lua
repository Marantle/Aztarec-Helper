-- Azta'rec Helper, copyright 2026 Rothirr, all rights reserved.
-- Read it if you want. Copying any of it into another addon is theft, and
-- running it through an AI tool first does not change that. The timings and
-- coordinates were measured by hand. Nothing here is licensed to anyone.

local _, AZT = ...

-- The answer keys doubling as the party signal: each press can put the
-- pressed quarter's marker on the player, so the group can follow along
-- without running the addon themselves, and when leading a party it can also
-- call that quarter in party chat for the follower boards, as its marker
-- number or as a direction word depending on the chosen style.
-- SetRaidTarget and chat sends from addon code are dead in the fight and
-- both have to travel Blizzard's secure macro path, so every key is
-- rerouted onto a hidden secure button whose canned macro does the say and
-- the marking.
-- The capture press still happens through PostClick and nothing about
-- answering changes.
--
-- Secure wiring is frozen during combat and can only move between pulls.
-- That is why the options arm for the whole fight and sermon presses mark
-- and call too. A sermon/echo split inside one pull cannot exist.

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

-- calling needs a party with real players and the lead. The route is the
-- leader's recording, two people calling would write over each other's boards
local function callActive()
    return AztarecHelperDB.callRoute and AZT.InPlayerParty() and UnitIsGroupLeader("player")
end

local function arm()
    owner = owner or CreateFrame("Frame")
    ClearOverrideBindings(owner)
    local me = UnitName("player")
    local callWith = callActive() and "/p"
    -- the dev solo rig calls through /say instead, so one account can run
    -- the whole leader-to-follower loop without a party
    if not callWith and AZT.Dev and AZT.Dev.callSay then
        callWith = "/s"
    end
    for q, cmd in pairs(QUAD_CMDS) do
        local keys = { GetBindingKey(cmd) }
        if #keys > 0 then
            local btn = button(q)
            -- the leader's synced icon wins, then the own pick, and a
            -- quarter shown as its plain letter still wears its seeded marker
            local icon = (AZT.Follow and AZT.Follow.IconFor(q))
                or (AztarecHelperDB.quadIcons and AztarecHelperDB.quadIcons[q])
                or AZT.MARK_SEED[q]
            local lines = {}
            if callWith then
                -- marking always speaks in icon numbers, only the call
                -- itself changes language
                local say = AztarecHelperDB.callStyle == "arrows" and AZT.QUAD_DIR[q] or icon
                lines[#lines + 1] = ("%s %s"):format(callWith, say)
            end
            if AztarecHelperDB.keysMark then
                lines[#lines + 1] = ("/targetexact %s\n/tm %d\n/targetlasttarget"):format(me, icon)
            end
            btn:SetAttribute("type", "macro")
            btn:SetAttribute("macrotext", table.concat(lines, "\n"))
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
    local want = AztarecHelperDB.keysMark or callActive() or (AZT.Dev and AZT.Dev.callSay)
    if want and AZT.InDelve() then
        arm()
    elseif armed then
        disarm()
    end
end

local rosterWait

ev:RegisterEvent("PLAYER_ENTERING_WORLD")
ev:RegisterEvent("ZONE_CHANGED_NEW_AREA")
ev:RegisterEvent("UPDATE_BINDINGS")
ev:RegisterEvent("GROUP_ROSTER_UPDATE")
ev:RegisterEvent("PARTY_LEADER_CHANGED")
ev:SetScript("OnEvent", function(_, event)
    if event == "GROUP_ROSTER_UPDATE" or event == "PARTY_LEADER_CHANGED" then
        -- roster events fire in bursts while a group forms, one rewire
        -- after they settle
        if rosterWait then
            rosterWait:Cancel()
        end
        rosterWait = C_Timer.NewTimer(0.5, AZT.MarkKeysSync)
        return
    end
    AZT.MarkKeysSync()
end)
