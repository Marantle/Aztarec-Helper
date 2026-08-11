-- Azta'rec Helper, copyright 2026 Rothirr, all rights reserved.
-- Read it if you want. Copying any of it into another addon is theft, and
-- running it through an AI tool first does not change that. The timings and
-- coordinates were measured by hand. Nothing here is licensed to anyone.

local _, AZT = ...

-- The follower half of party play. The leader's answer keys call each
-- quarter's marker number in party chat (Core/MarkKeys.lua builds that
-- macro) and this side collects the calls and draws the route. In the fight
-- those payloads are secret: they can be stored and rendered through the
-- stock marker textures but never read, so nothing here inspects a message
-- and nothing can filter one. The follower's own wave machinery still
-- tracks the boss, which is what slots the calls and times the display.

local Follow = {}
AZT.Follow = Follow

-- the stock texture path with its number slot opened up for a secret
local MARK_FMT = AZT.MARK_TEX:gsub("%%d", "%%s")

-- the stock icon art sits inset in its file with empty margin around it,
-- cropping 4..60 draws the marker solid at display size instead of washed
local function iconEscape(size)
    return "\124T" .. MARK_FMT .. ":" .. size .. ":" .. size .. ":0:0:64:64:4:60:4:60\124t"
end

local BOARD_H = 68
local ICON_NOW = 62 -- the echo being counted down, pinned at the left edge
local ICON_REST = 20 -- while collecting, everything received so far
local ICON_NEXT = 14 -- echoes still to come trail off to the right

local arr = {} -- the calls, secret values slotted by wave
local filled = {} -- plain booleans so drawing never has to touch a secret
local count = 0
local following = false -- latched at each sermon start, held for the pull
local prevPhase

-- DevTools flips this: follower role without a group, collecting /say too,
-- so one account can play both ends of the loop
Follow.testSolo = false

-- The leader's quarter icons ride along on addon messages, sent out of
-- combat where the pipe is open, so the whole party's room views, boards
-- and self-marks speak the leader's icon language. This syncs regardless
-- of the calling and following modes but only inside the delve, nothing
-- about the addon talks or listens outside it. A member arriving after the
-- leader's broadcast asks for the set once, so entry order does not
-- matter. Display overlay only, everyone's own choices stay untouched in
-- their saved variables.
local PREFIX = "AztarecHelper"
local leaderIcons
local iconsActive = false
local iconsRequested = false

C_ChatInfo.RegisterAddonMessagePrefix(PREFIX)

function Follow.IconFor(q)
    if iconsActive and leaderIcons then
        return leaderIcons[q]
    end
end

local function refreshIcons()
    if AZT.SetSafeQuads then
        AZT.SetSafeQuads(AZT.Safe and AZT.Safe.GetSequence() or nil)
    end
    AZT.MarkKeysSync()
end

local function sendAddon(msg)
    if InCombatLockdown() or C_ChatInfo.InChatMessagingLockdown() then
        return -- sends are dead in the fight, the next delve sync retries
    end
    local chan = IsInGroup(LE_PARTY_CATEGORY_INSTANCE) and "INSTANCE_CHAT" or "PARTY"
    -- protected during boss encounters, the lockdown check above should
    -- keep this call out of there but the repo rule is pcall regardless
    pcall(C_ChatInfo.SendAddonMessage, PREFIX, msg, chan)
end

function Follow.SendIcons()
    if not (AZT.InPlayerParty() and UnitIsGroupLeader("player") and AZT.InDelve()) then
        return
    end
    local icons = AztarecHelperDB.quadIcons or {}
    sendAddon(("icons %d %d %d %d"):format(icons.N or 0, icons.E or 0, icons.S or 0, icons.W or 0))
end

-- the name of whoever leads, for checking a message really came from them
local function leaderName()
    if UnitIsGroupLeader("player") then
        return (UnitName("player"))
    end
    for i = 1, 4 do
        local unit = "party" .. i
        if UnitExists(unit) and UnitIsGroupLeader(unit) then
            return (UnitName(unit))
        end
    end
end

local function onAddon(prefix, msg, _, sender)
    if prefix ~= PREFIX then
        return
    end
    -- in the fight a payload is secret and pattern matching on one throws.
    -- Sends are dead mid fight anyway, so a secret here is noise to drop
    if issecretvalue and issecretvalue(msg) then
        return
    end
    if msg == "icons?" then
        if UnitIsGroupLeader("player") then
            Follow.SendIcons()
        end
        return
    end
    -- icon sets are believed from the leader alone. The realm gets stripped
    -- for the compare since the sender carries it and UnitName does not,
    -- and a cross realm name twin inside one five man is not a real worry
    if not sender or sender:match("^[^-]+") ~= leaderName() then
        return
    end
    local n, e, s, w = msg:match("^icons (%d) (%d) (%d) (%d)$")
    if not n then
        return
    end
    leaderIcons = {}
    for q, v in pairs({ N = n, E = e, S = s, W = w }) do
        v = tonumber(v)
        if v and v >= 1 and v <= 8 then
            leaderIcons[q] = v
        end
    end
    refreshIcons()
end

local board
local redraw

local function buildBoard()
    board = CreateFrame("Frame", "AztarecHelperFollowBoard", UIParent)
    board:SetSize(300, BOARD_H)
    -- the default puts the current call itself on the screen's centerline,
    -- a touch above the character, so the offset carries the head's inset
    AZT.MakeMovable(board, "followPos", "CENTER", 150 - 8 - ICON_NOW / 2, 120)
    local bg = board:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetColorTexture(0, 0, 0, 0.25)
    -- the current call sits pinned at the board's left edge so nothing dead
    -- sits left of it, and what is still coming files in from its right
    board.now = board:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    board.now:SetPoint("LEFT", board, "LEFT", 8, 0)
    board.trail = board:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    board.trail:SetPoint("LEFT", board.now, "RIGHT", 8, 0)
    AZT.AttachLock(board, "follow")
    board:Hide()
end

-- a slice of the received route into one fontstring. A build can revoke a
-- sink's secret permission at any patch, so the fallback keeps the board
-- honest instead of erroring on every redraw
local function drawSlice(fs, first, last, size)
    local parts = {}
    local args = {}
    for i = first, last do
        if filled[i] then
            parts[#parts + 1] = iconEscape(size)
            args[#args + 1] = arr[i]
        else
            parts[#parts + 1] = "?"
        end
    end
    if not pcall(fs.SetFormattedText, fs, table.concat(parts, "  "), unpack(args)) then
        fs:SetText("route hidden this build")
    end
end

-- a party's leader cannot follow, their calls are the thing followed. The
-- toggle survives lead swaps, it just sits inert while you lead
local function couldFollow()
    return AztarecHelperDB.follow and not (AZT.InPlayerParty() and UnitIsGroupLeader("player"))
end

redraw = function()
    local w = AZT.Wave
    local live = following and w.phase ~= nil
    -- parked asks for no party, the stand-in is how the board gets placed
    local parked = (couldFollow() or Follow.testSolo) and AZT.InDelve() and not AZT.Fighting()
    local on = live or parked
    if not board then
        if not on then
            return
        end
        buildBoard()
    end
    board:SetShown(on)
    if not on then
        return
    end
    board.now:SetTextColor(1, 1, 1, 1)
    board.now:SetAlpha(1)
    board.trail:SetTextColor(1, 1, 1, 1)
    board.trail:SetText("")
    if not live then
        -- a stand-in where the live call will sit, drawn exactly like the
        -- real thing so placing the board shows what a call will look like.
        -- The caption alone carries the parked look
        board.now:SetFormattedText(iconEscape(ICON_NOW), "1")
        board.trail:SetText("leader's route")
        board.trail:SetTextColor(1, 1, 1, 0.5)
        return
    end
    local top = math.max(count, w.total or 0)
    if top == 0 then
        board.now:SetText("waiting for calls")
        board.now:SetTextColor(1, 1, 1, 0.8)
        return
    end
    local current = w.phase == "echo" and w.idx or 0
    if current == 0 then
        -- still collecting. The opener draws big from the moment it lands,
        -- since that is the one the echoes will start with
        drawSlice(board.now, 1, 1, ICON_NOW)
        if top > 1 then
            drawSlice(board.trail, 2, top, ICON_REST)
        end
    else
        -- the current call holds the head slot and the rest files in from
        -- the right
        drawSlice(board.now, current, current, ICON_NOW)
        if current < top then
            drawSlice(board.trail, current + 1, top, ICON_NEXT)
        end
    end
end

-- a call lands in the window the boss is on, so a leader double-press
-- corrects in place and chat noise garbles one slot instead of shifting the
-- route. During the echoes a late call backfills the earliest hole, the
-- same rule the leader's own capture uses
local function onCall(text)
    if not following then
        return
    end
    local w = AZT.Wave
    if w.phase == "record" then
        local i = w.idx
        if i and i >= 1 then
            arr[i] = text
            filled[i] = true
            if i > count then
                count = i
            end
        end
    elseif w.phase == "echo" then
        for i = 1, math.max(count, w.total or 0) do
            if not filled[i] then
                arr[i] = text
                filled[i] = true
                if i > count then
                    count = i
                end
                break
            end
        end
    else
        return
    end
    redraw()
end

-- called from SafeSpots' setWave fan-out, so it sees every phase and index
-- change. A new sermon wipes the board and decides the role for this pull
function AZT.FollowSync()
    local w = AZT.Wave
    if w.phase == "record" and prevPhase ~= "record" then
        wipe(arr)
        wipe(filled)
        count = 0
        following = Follow.testSolo
            or (AztarecHelperDB.follow and AZT.InPlayerParty() and not UnitIsGroupLeader("player") and AZT.InDelve())
    end
    prevPhase = w.phase
    redraw()
end

-- the one question everything follower mode locks off asks: the option and
-- the solo rig suppress outright, and a latched pull suppresses while it
-- runs
function Follow.Suppress()
    return couldFollow() or Follow.testSolo or (following and AZT.Wave.phase ~= nil)
end

-- WaveText hands its composed line through here during a followed fight and
-- gets the leader's icons in place of the local quarters. False means the
-- caller should fall through to its normal rendering
function Follow.DecorateWaveLine(fs, msg, alpha)
    local w = AZT.Wave
    if not following or w.phase ~= "echo" or not filled[w.idx] then
        return false
    end
    local fmt = iconEscape(ICON_REST) .. "  " .. msg:gsub("%%", "%%%%")
    local args = { arr[w.idx] }
    if filled[w.idx + 1] then
        fmt = fmt .. "  >  " .. iconEscape(16)
        args[#args + 1] = arr[w.idx + 1]
    end
    local ok = pcall(fs.SetFormattedText, fs, fmt, unpack(args))
    if ok then
        fs:SetTextColor(1, 1, 1, alpha)
    end
    return ok
end

-- chat events only stay registerd while the option, a group and the delve
-- line up. All insecure code, so unlike the leader's rig this can move in
-- combat freely
local CHAT_EVENTS = {
    "CHAT_MSG_PARTY",
    "CHAT_MSG_PARTY_LEADER",
    "CHAT_MSG_INSTANCE_CHAT",
    "CHAT_MSG_INSTANCE_CHAT_LEADER",
}

local ev = CreateFrame("Frame")
local rosterWait
local askedRole -- session only, the offer returns whenever the role flips

function Follow.Sync()
    if not AztarecHelperDB then
        return
    end
    local want = ((couldFollow() and AZT.InPlayerParty()) or Follow.testSolo) and AZT.InDelve()
    for _, e in ipairs(CHAT_EVENTS) do
        if want then
            ev:RegisterEvent(e)
        else
            ev:UnregisterEvent(e)
        end
    end
    -- the solo rig listens to /say as well, since that is where its own
    -- calls go out
    if want and Follow.testSolo then
        ev:RegisterEvent("CHAT_MSG_SAY")
    else
        ev:UnregisterEvent("CHAT_MSG_SAY")
    end
    -- the icon sync runs on party membership in the delve and modes play
    -- no part. Members without the set yet ask the leader for it once
    local party = AZT.InPlayerParty() and AZT.InDelve()
    if party then
        ev:RegisterEvent("CHAT_MSG_ADDON")
    else
        ev:UnregisterEvent("CHAT_MSG_ADDON")
        iconsRequested = false
    end
    if not AZT.InPlayerParty() then
        leaderIcons = nil
    end
    local wasActive = iconsActive
    iconsActive = party and not UnitIsGroupLeader("player")
    if iconsActive ~= wasActive then
        refreshIcons()
    end
    if iconsActive and not leaderIcons and not iconsRequested then
        iconsRequested = true
        sendAddon("icons?")
    end
    Follow.SendIcons()
    redraw()
    if AZT.RefreshOptions then
        AZT.RefreshOptions()
    end
    -- the offers follow the role: become the leader and calling comes up,
    -- drop to member and following does, each at most once per stint in
    -- that role and only while the matching option is off
    local role
    if AZT.InDelve() and AZT.InPlayerParty() then
        role = UnitIsGroupLeader("player") and "leader" or "member"
    end
    if role ~= askedRole then
        if not role then
            askedRole = nil
        elseif InCombatLockdown() then
            ev:RegisterEvent("PLAYER_REGEN_ENABLED")
        else
            askedRole = role
            if role == "leader" and not AztarecHelperDB.callRoute then
                AZT.ShowCallAsk()
            elseif role == "member" and not AztarecHelperDB.follow then
                AZT.ShowFollowAsk()
            end
        end
    end
end

-- the two roles cannot mix, so flipping one on drops the other. Every
-- surface that toggles the modes comes through these two
function AZT.SetCallRoute(on)
    AztarecHelperDB.callRoute = on
    if on and AztarecHelperDB.follow then
        AztarecHelperDB.follow = false
        Follow.Sync()
        AZT.ArrowSync()
        AZT.chat("following the leader: OFF - one role at a time")
    end
    AZT.MarkKeysSync()
end

function AZT.SetFollow(on)
    AztarecHelperDB.follow = on
    if on and AztarecHelperDB.callRoute then
        AztarecHelperDB.callRoute = false
        AZT.MarkKeysSync()
        AZT.chat("route calling: OFF - one role at a time")
    end
    Follow.Sync()
    AZT.ArrowSync()
end

ev:SetScript("OnEvent", function(_, event, ...)
    if event == "GROUP_ROSTER_UPDATE" or event == "PARTY_LEADER_CHANGED" then
        -- fires in bursts while a group forms, one sync after they settle
        if rosterWait then
            rosterWait:Cancel()
        end
        rosterWait = C_Timer.NewTimer(0.5, Follow.Sync)
    elseif event == "PLAYER_ENTERING_WORLD" or event == "ZONE_CHANGED_NEW_AREA" then
        Follow.Sync()
    elseif event == "PLAYER_REGEN_ENABLED" then
        ev:UnregisterEvent("PLAYER_REGEN_ENABLED")
        Follow.Sync()
    elseif event == "CHAT_MSG_ADDON" then
        onAddon(...)
    else
        onCall(...)
    end
end)
ev:RegisterEvent("PLAYER_ENTERING_WORLD")
ev:RegisterEvent("ZONE_CHANGED_NEW_AREA")
ev:RegisterEvent("GROUP_ROSTER_UPDATE")
ev:RegisterEvent("PARTY_LEADER_CHANGED")
