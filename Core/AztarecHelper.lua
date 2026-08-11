-- Azta'rec Helper, copyright 2026 Rothirr, all rights reserved.
-- Read it if you want. Copying any of it into another addon is theft, and
-- running it through an AI tool first does not change that. The timings and
-- coordinates were measured by hand. Nothing here is licensed to anyone.

local ADDON, AZT = ...

AZT.VERSION = "1.4.0"

-- Venomfall Deeps boss room, measured on PTR 12.1.0.
-- UnitPosition returns (a, b, z, inst). The addon prints them as world=b,a.
-- Axis a points NORTH, axis b points WEST. Facing = radians CCW from north.
AZT.ROOM = {
    instanceMapID = 3079,
    uiMapID = 2634,
    centerA = 181.70, -- first UnitPosition return at room center
    centerB = 0.60, -- second UnitPosition return at room center
    radius = 36, -- wall distance from center (yd)
    pad = 15, -- extra view drawn beyond the wall (yd)
    -- uiMap 2634's picture in world yards, top-left corner and spans. The
    -- room view aligns the map art with these, re-measuring when it can.
    mapOriginA = 305,
    mapSpanA = 340,
    mapOriginB = 255,
    mapSpanB = 510,
}

local DEFAULTS = {
    enabled = true,
    autoRecord = true, -- start/stop recording with combat automatically
    nameFilter = "", -- substring filter for target/nameplate casts, "" logs every hostile cast
    posOnCast = true, -- append a player position probe to every cast line
    roomView = true, -- the main room view window
    roomSlim = false, -- room view without its title and buttons
    mapArt = false, -- draw Blizzard's map art tiles behind the room view
    waveText = true, -- floating wave countdown window
    arrow = true, -- quest-style arrow showing the move for each echo
    arrowColor = "gold", -- key into AZT.ARROW_COLORS
    arrowCompass = false, -- arrow points the way the room view does, no spoken cues
    cues = true, -- spoken cues during the echoes
    keysMark = false, -- answer keys also mark the player for the party
    callRoute = false, -- leader: answer keys also call the quarter's number in party chat
    follow = false, -- follower: collect the leader's calls and show the route
    cueChannel = "Master", -- sound channel the calls play through
    quadIcons = {}, -- world marker icon per quarter letter, board display only
    anywhere = false, -- escape hatch: treat every zone as the delve
    log = {}, -- persisted log lines (survive /reload and crashes)
}

local f = CreateFrame("Frame")
f:RegisterEvent("ADDON_LOADED")
f:RegisterEvent("PLAYER_LOGIN")

f:SetScript("OnEvent", function(_, event, ...)
    if event == "ADDON_LOADED" then
        local name = ...
        if name ~= ADDON then
            return
        end
        AztarecHelperDB = AztarecHelperDB or {}
        for k, v in pairs(DEFAULTS) do
            if AztarecHelperDB[k] == nil then
                AztarecHelperDB[k] = v
            end
        end
        if type(AztarecHelperDB.log) ~= "table" then
            AztarecHelperDB.log = {}
        end
        -- the grid rotation toggle is gone so clear its leftovers from old SVs
        AztarecHelperDB.quadRot = nil
        AztarecHelperDB.quadRotMigrated = nil
        if not AztarecHelperDB.mapArtOffOnce then
            AztarecHelperDB.mapArtOffOnce = true
            AztarecHelperDB.mapArt = false
        end
        if not AztarecHelperDB.quadIconsSeeded then
            AztarecHelperDB.quadIconsSeeded = true
            if next(AztarecHelperDB.quadIcons) == nil then
                for q, i in pairs(AZT.MARK_SEED) do
                    AztarecHelperDB.quadIcons[q] = i
                end
            end
        end
        -- 1.3.0 removed everything position-fed: auto sampling, the manual
        -- toggle, the move warning and the view modes. Clear their leftovers
        AztarecHelperDB.manualMode = nil
        AztarecHelperDB.moveWarn = nil
        AztarecHelperDB.viewMode = nil
        AztarecHelperDB.viewModeMigrated = nil
        AztarecHelperDB.keyDebug = nil
        -- Talking Head was never a channel PlaySoundFile accepts
        if AztarecHelperDB.cueChannel == "Talking Head" then
            AztarecHelperDB.cueChannel = "Master"
        end
        -- 1.3.4 muted the spoken cues under the compass arrow and 1.3.6
        -- unmutes them. Anyone already on the compass keeps their cue
        -- toggle as it stands and skips the ask box new compass users get
        if AztarecHelperDB.arrowCompass then
            AztarecHelperDB.compassCueAsked = true
        end
    elseif event == "PLAYER_LOGIN" then
        if AZT.Recorder then
            AZT.Recorder.Init()
        end
    end
end)

local function chat(msg)
    print("|cff33ff99AZT|r: " .. msg)
end
AZT.chat = chat

-- Are we in the nemesis delve? The instance map id is the primary signal.
-- The zone name is the fallback in case Blizzard renumbers it for live, and
-- /azt anywhere overrides the whole question for the day both signals break.
function AZT.InDelve()
    if AztarecHelperDB and AztarecHelperDB.anywhere then
        return true
    end
    local ok, _, _, _, _, _, _, _, instMapID = pcall(GetInstanceInfo)
    if ok and instMapID == AZT.ROOM.instanceMapID then
        return true
    end
    local okZ, zt = pcall(GetZoneText)
    return (okZ and zt == "Venomfall Deeps") or false
end

-- The recon logger lives in DevTools.lua, which is not shipped. It overrides
-- this with the real recorder. Shipped builds silently drop log lines.
function AZT.Log() end

-- is a fight on by any signal: the regen flag, the lockdown API or an
-- armed encounter. Every parked window hides behind this one answer
function AZT.Fighting()
    return AZT.inCombat or InCombatLockdown() or (AZT.Safe and AZT.Safe.IsArmed and AZT.Safe.IsArmed()) or false
end

-- a delve companion NPC counts as a group to IsInGroup, so party play asks
-- the roster for an actual player before believing it
function AZT.InPlayerParty()
    if not IsInGroup() or IsInRaid() then
        return false
    end
    for i = 1, 4 do
        local unit = "party" .. i
        if UnitExists(unit) and UnitIsPlayer(unit) then
            return true
        end
    end
    return false
end

-- world marker flags carry the same eight symbols as the raid target icons
AZT.MARK_TEX = "Interface\\TargetingFrame\\UI-RaidTargetingIcon_%d"

-- the icons a fresh install wears: triangle north, square east, cross south,
-- circle west. The seeding and the mark keys' letter fallback both read this
AZT.MARK_SEED = { N = 4, E = 6, S = 7, W = 2 }

-- a quarter as the player sees it: the party leader's icon when one is
-- synced over, else the marker icon they picked for it or the compass
-- letter. Everything that names a quarter goes through here so the board,
-- the arrow and the chat lines all speak the same language.
function AZT.QuadName(q, size)
    local idx = (AZT.Follow and AZT.Follow.IconFor(q)) or (AztarecHelperDB.quadIcons and AztarecHelperDB.quadIcons[q])
    if idx then
        return ("|T" .. AZT.MARK_TEX .. ":%d|t"):format(idx, size or 14)
    end
    return q
end

local HELP = {
    "/azt room          - toggle the room view (auto-shows in the delve)",
    "/azt map           - toggle the map art backdrop behind the room view",
    "/azt n|e|s|w       - answer a wave with that quarter (bindable keys too)",
    "/azt replay        - practice: replay the last recorded route with real timings",
    "/azt cue           - toggle the spoken cues during the echoes",
    "/azt call          - toggle calling the route for the party while you lead",
    "/azt follow        - toggle following the leader's calls",
    "/azt review        - what the last pull recorded and where you died",
    "/azt reset         - clear the recorded route",
    "/azt options       - open the settings panel",
    "/azt anywhere      - treat where you stand as the delve, for when detection breaks",
    "/azt help          - how the recording and the callouts work",
    "/azt version       - addon version",
}
AZT.HELP = HELP -- DevTools.lua appends its command list when present

SLASH_AZT1 = "/azt"
SlashCmdList["AZT"] = function(msg)
    msg = msg or ""
    local cmd, rest = msg:match("^(%S*)%s*(.-)%s*$")
    cmd = cmd:lower()

    if cmd == "room" then
        AZT.ToggleRoomView()
    elseif cmd == "map" then
        AZT.ToggleMapArt()
    elseif cmd == "n" or cmd == "e" or cmd == "s" or cmd == "w" then
        AZT.Safe.CaptureQuadrant(cmd:upper())
    elseif cmd == "replay" then
        AZT.Safe.Replay()
    elseif cmd == "anywhere" then
        AztarecHelperDB.anywhere = not AztarecHelperDB.anywhere
        -- everything zone gated re-decides right now instead of waiting for
        -- the next zone change
        if AZT.Safe and AZT.Safe.ZoneSync then
            AZT.Safe.ZoneSync()
        end
        AZT.MarkKeysSync()
        if AZT.Follow then
            AZT.Follow.Sync()
        end
        if AZT.RoomZoneSync then
            AZT.RoomZoneSync()
        end
        if AztarecHelperDB.anywhere then
            chat("treating every zone as the delve - costs idle work, /azt anywhere again to turn off")
        else
            chat("back to delve detection")
        end
    elseif cmd == "cue" then
        AztarecHelperDB.cues = not AztarecHelperDB.cues
        chat("spoken cues: " .. (AztarecHelperDB.cues and "ON" or "OFF"))
    elseif cmd == "call" then
        -- calling belongs to the leader alone. The command refuses
        -- anyone else so two routes never fight over the boards
        if not AztarecHelperDB.callRoute and not (AZT.InPlayerParty() and UnitIsGroupLeader("player")) then
            chat("route calling is for the party leader - take the lead first")
        else
            AZT.SetCallRoute(not AztarecHelperDB.callRoute)
            if AztarecHelperDB.callRoute then
                chat(
                    "route calling: ON - ask the party to keep chat quiet in the fight, stray lines land on their boards"
                )
            else
                chat("route calling: OFF")
            end
        end
    elseif cmd == "follow" then
        if not AztarecHelperDB.follow and AZT.InPlayerParty() and UnitIsGroupLeader("player") then
            chat("following is for party members - you lead, call the route instead")
        else
            AZT.SetFollow(not AztarecHelperDB.follow)
            chat("following the leader: " .. (AztarecHelperDB.follow and "ON" or "OFF"))
        end
    elseif cmd == "review" then
        AZT.Safe.Review()
    elseif cmd == "reset" then
        AZT.Safe.Reset()
        chat("recorded route cleared")
    elseif cmd == "options" or cmd == "opt" then
        AZT.OpenOptions()
    elseif cmd == "help" then
        AZT.ShowInstructions()
    elseif cmd == "version" then
        chat(ADDON .. " v" .. AZT.VERSION)
    elseif AZT.Dev and AZT.Dev.HandleCommand(cmd, rest) then -- luacheck: ignore 542
        -- handled by DevTools.lua
    else
        chat("commands:")
        for _, line in ipairs(HELP) do
            print("  " .. line)
        end
    end
end

-- global for the AddOn Compartment entry in the .toc
function AztarecHelper_OnCompartment()
    AZT.OpenOptions()
end
