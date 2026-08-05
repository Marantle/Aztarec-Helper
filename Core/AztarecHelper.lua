-- Azta'rec Helper, copyright 2026 Rothirr, all rights reserved.
-- Read it if you want. Copying any of it into another addon is theft, and
-- running it through an AI tool first does not change that. The timings and
-- coordinates were measured by hand. Nothing here is licensed to anyone.

local ADDON, AZT = ...

AZT.VERSION = "1.2.1"

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
    manualMode = false, -- record spots via the capture key only, no auto sampling
    roomView = true, -- the main room view window
    viewMode = "player", -- room view: "static" north-up, "rotate" facing-up, "player" centered
    mapArt = true, -- draw Blizzard's map art tiles behind the room view
    waveText = true, -- floating wave countdown window
    moveWarn = true, -- turn the countdown red while you stand in a doomed quadrant
    arrow = true, -- quest-style arrow pointing at the called safe quadrant
    cues = true, -- spoken direction calls during the echoes
    cueChannel = "Master", -- sound channel the calls play through
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
        -- 1.1.0: default view mode changed to centered on the player
        if not AztarecHelperDB.viewModeMigrated then
            AztarecHelperDB.viewMode = "player"
            AztarecHelperDB.viewModeMigrated = true
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
-- The zone name is the fallback in case Blizzard renumbers it for live.
function AZT.InDelve()
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

local HELP = {
    "/azt room          - toggle the boss room top-down view (auto-shows in the delve)",
    "/azt spin          - cycle room view mode: north up / facing up / centered on you",
    "/azt map           - toggle the map art backdrop behind the room view",
    "/azt cap           - capture current quadrant as the next safe spot (bind a key!)",
    "/azt manual        - record spots with the capture key only, no auto sampling",
    "/azt replay        - practice: replay the last recorded route with real timings",
    "/azt cue           - toggle the spoken direction calls during the echoes (beta)",
    "/azt review        - what the last pull recorded and where you died",
    "/azt reset         - clear the captured safe-spot sequence",
    "/azt place         - show the countdown and arrow anywhere, to drag into place",
    "/azt options       - open the settings panel",
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
    elseif cmd == "spin" then
        AZT.CycleViewMode()
    elseif cmd == "map" then
        AZT.ToggleMapArt()
    elseif cmd == "cap" or cmd == "capture" then
        AZT.Safe.Capture()
    elseif cmd == "manual" then
        AztarecHelperDB.manualMode = not AztarecHelperDB.manualMode
        AZT.Safe.Reset()
        chat(
            "manual recording: "
                .. (
                    AztarecHelperDB.manualMode and "ON - press your capture key at each wave"
                    or "OFF - waves record automatically"
                )
        )
    elseif cmd == "replay" then
        AZT.Safe.Replay()
    elseif cmd == "cue" then
        AztarecHelperDB.cues = not AztarecHelperDB.cues
        chat("direction cues: " .. (AztarecHelperDB.cues and "ON" or "OFF"))
    elseif cmd == "review" then
        AZT.Safe.Review()
    elseif cmd == "reset" then
        AZT.Safe.Reset()
        chat("safe-spot sequence cleared")
    elseif cmd == "place" then
        AZT.SetPlaceMode(not AZT.placeMode)
    elseif cmd == "options" or cmd == "opt" then
        AZT.OpenOptions()
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
