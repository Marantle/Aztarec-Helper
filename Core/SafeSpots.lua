-- Azta'rec Helper, copyright 2026 Rothirr, all rights reserved.
-- Read it if you want. Copying any of it into another addon is theft, and
-- running it through an AI tool first does not change that. The timings and
-- coordinates were measured by hand. Nothing here is licensed to anyone.

local _, AZT = ...

-- Safe-spot tracking for the Azta'rec wave mechanic. While the boss channels,
-- a capture window opens per wave on the measured hit grid and the player
-- keys the quarter they run to. When the hidden echoes start right after the
-- channel, each cast start calls the recording back.

local Safe = {}
AZT.Safe = Safe

BINDING_HEADER_AZTARECHELPER = "Azta'rec Helper"
-- display names only. The MARK command ids stay, renaming those drops keybinds
BINDING_NAME_AZTARECHELPER_MARK_NORTH = "Azta'rec Helper: answer north"
BINDING_NAME_AZTARECHELPER_MARK_EAST = "Azta'rec Helper: answer east"
BINDING_NAME_AZTARECHELPER_MARK_SOUTH = "Azta'rec Helper: answer south"
BINDING_NAME_AZTARECHELPER_MARK_WEST = "Azta'rec Helper: answer west"

local seq = {}
local armed = false

-- capture state
local ticker
local winIdx = 0
local chanStartT = 0
-- per-difficulty cone hit grids (offsets after CHAN_START), measured via
-- deliberate deaths on the PTR. Both difficulties end the channel ~0.5s
-- after the last hit. Wave count grows per channel, so windows keep opening
-- until the channel actually stops.
local GRIDS = {
    [3508] = { first = 3.04, spacing = 3.5 }, -- "?"
    [3525] = { first = 2.50, spacing = 3.01 }, -- "??"
}
local grid = GRIDS[3508]
local MAX_WAVES = 10
local LOCK_DELAY = 0.8 -- the window closes this long after its hit
local chanUnit = nil -- unit token that ran the channel, its casts are the echoes
local capturing = false -- a channel is being recorded
local lastPull -- most recent recorded route, kept for review and replay

local REPLAY_LEAD = 1.8 -- pause before a replay's first wave
local REPLAY_TAIL = 1.8 -- how long the last replay wave stays lit

-- what the wave countdown renders. One table, fields overwritten in place.
local wave = { phase = nil, idx = 0, total = nil, at = nil }
AZT.Wave = wave

local function setWave(phase, idx, total, at, startedAt, gap)
    wave.phase, wave.idx, wave.total, wave.at = phase, idx, total, at
    -- when the echo started and how long the last one ran. The encounter
    -- hides cast end times, so this pair is the only handle on when the
    -- next call is due.
    wave.startedAt, wave.gap = startedAt, gap
    if AZT.WaveSync then
        AZT.WaveSync()
    end
    if AZT.ArrowSync then
        AZT.ArrowSync()
    end
    if AZT.QuadClickSync then
        AZT.QuadClickSync()
    end
end

local function hitTime(i)
    return grid.first + grid.spacing * (i - 1)
end

-- echo state
local echoIdx = 0
local echoUntil = 0
local lastEchoAdvance = 0

-- cardinal quarters, each spanning the 90 degrees centered on its name
local QUADRANTS = { "N", "E", "S", "W" }

function Safe.GetSequence()
    return seq
end

local function seqText()
    return #seq > 0 and table.concat(seq, "  >  ") or "?"
end

local QUAD_INDEX = {}
for i, q in ipairs(QUADRANTS) do
    QUAD_INDEX[q] = i
end
local TURNS = { [0] = "stay", "left", "forward", "right" }

-- Where the safe quarter is from the player's view, assuming they are looking
-- at the boss in the middle. The far quarter is straight through him.
function Safe.TurnFromTo(from, to)
    local a, b = QUAD_INDEX[from], QUAD_INDEX[to]
    if not a or not b then
        return nil
    end
    return TURNS[(b - a) % 4]
end

--#region Capture

local function stopTicker()
    if ticker then
        ticker:Cancel()
        ticker = nil
    end
end

-- keep a copy of the route for review and replay, since the live table gets
-- wiped the moment the next channel starts
local function snapshotPull()
    if #seq == 0 then
        return
    end
    lastPull = { seq = {}, grid = grid, death = nil }
    for i, q in ipairs(seq) do
        lastPull.seq[i] = q
    end
end

-- the window walk. The ticker advances the wave index for the countdown
-- display and closes windows the player never answered, every spot comes fromt
-- the quarter keys.
local function beginCapture(unit)
    stopTicker()
    wipe(seq)
    chanUnit = unit
    chanStartT = GetTime()
    capturing = true
    winIdx = 1
    if AZT.SetSafeQuads then
        AZT.SetSafeQuads(seq)
    end
    ticker = C_Timer.NewTicker(0.2, function()
        if winIdx > MAX_WAVES then
            return
        end
        local elapsed = GetTime() - chanStartT
        setWave("record", winIdx, nil, chanStartT + hitTime(winIdx))
        if elapsed >= hitTime(winIdx) + LOCK_DELAY then
            if seq[winIdx] == nil then
                seq[winIdx] = "?"
                AZT.Log(("WINDOW %d closed with no input"):format(winIdx))
            end
            winIdx = winIdx + 1
            if AZT.SetSafeQuads then
                AZT.SetSafeQuads(seq)
            end
        end
    end)
    AZT.Log("CAPTURE open - answer each wave with the quarter you run to")
end

local function finishCapture()
    capturing = false
    if not ticker then
        return
    end
    stopTicker()
    local elapsed = GetTime() - chanStartT
    if elapsed < 8 then
        -- real wave channels run 10.5s or longer. Something shorter slipped
        -- through the filters (or the boss died) - discard, don't replay
        AZT.Log(("CHANNEL discarded after %.1fs - not the wave mechanic"):format(elapsed))
        Safe.Reset()
        return
    end
    -- close out to the last hit that landed. Unkeyed waves stay "?" and
    -- their echoes show as unknown, there is nothing to reconstruct from
    -- when the player is the only sensor
    while winIdx <= MAX_WAVES and hitTime(winIdx) <= elapsed + 0.6 do
        if seq[winIdx] == nil then
            seq[winIdx] = "?"
        end
        winIdx = winIdx + 1
    end
    AZT.Log(("CAPTURE closed after %.1fs: %s"):format(elapsed, seqText()))
    if AZT.SetSafeQuads then
        AZT.SetSafeQuads(seq)
    end
    snapshotPull()
    setWave(nil, 0, nil, nil)
    echoIdx = 0
    echoUntil = GetTime() + 10 + 5 * #seq
    lastEchoAdvance = 0
    -- if the run goes stale (the boss stopped echoing short of the full
    -- route), clear the display rather than keep pointing at a wave that is
    -- never coming. A newer channel makes this timer a no-op.
    local window = echoUntil
    C_Timer.NewTimer(10 + 5 * #seq + 2, function()
        if not capturing and echoUntil == window and echoIdx < #seq then
            Safe.Reset()
        end
    end)
end

-- quarter keys: the player names the quarter outright, no position read
-- anywhere. Answers land in order. The earliest wave still unanswered takes
-- the press, and nothing can be answered before its wave has happened, so
-- missing one and tapping twice gets you level again instead of shifting
-- the whole route. A wave still blank when the echoes start can be filled
-- right up until its own echo plays. Outside a channel it appends, for
-- walking a route in by hand between pulls.
local function fillSpot(i, q, caught)
    seq[i] = q
    AZT.Log(("SAFESPOT answered %d = %s%s"):format(i, q, caught and " (caught up)" or ""))
    AZT.chat(("safe spot %d: %s"):format(i, AZT.QuadName(q, 14)))
    if AZT.SetSafeQuads then
        AZT.SetSafeQuads(seq, echoIdx > 0 and echoIdx or nil)
    end
end

function Safe.CaptureQuadrant(q)
    if not QUAD_INDEX[q] then
        return
    end
    -- how far the boss has actually got: the open window while the channel
    -- runs, the whole recorded route once it has stopped
    local limit = capturing and math.min(winIdx, MAX_WAVES) or #seq
    for i = 1, limit do
        if seq[i] == nil or seq[i] == "?" then
            fillSpot(i, q, i < limit)
            return
        end
    end
    if capturing and limit >= 1 then
        -- level with the boss, so the press corrects the wave in front of you
        fillSpot(limit, q)
        return
    end
    if echoIdx > 0 then
        return
    end
    if #seq >= MAX_WAVES then
        wipe(seq)
    end
    fillSpot(#seq + 1, q)
end

-- globals for Bindings.xml, one per quarter
function AztarecHelper_MarkNorth()
    Safe.CaptureQuadrant("N")
end

function AztarecHelper_MarkEast()
    Safe.CaptureQuadrant("E")
end

function AztarecHelper_MarkSouth()
    Safe.CaptureQuadrant("S")
end

function AztarecHelper_MarkWest()
    Safe.CaptureQuadrant("W")
end

function Safe.Reset()
    stopTicker()
    Safe.StopReplay()
    wipe(seq)
    chanUnit = nil
    capturing = false
    winIdx = 0
    echoIdx = 0
    echoUntil = 0
    setWave(nil, 0, nil, nil)
    if AZT.SetSafeQuads then
        AZT.SetSafeQuads(seq)
    end
end

function Safe.IsArmed()
    return armed
end

--#endregion

--#region Review

function Safe.Review()
    if not lastPull then
        AZT.chat("nothing recorded yet - pull the boss once first")
        return
    end
    local parts, missed = {}, 0
    for i, q in ipairs(lastPull.seq) do
        parts[i] = AZT.QuadName(q, 14)
        if q == "?" then
            missed = missed + 1
        end
    end
    AZT.chat("last pull: " .. table.concat(parts, "  >  "))
    if missed > 0 then
        AZT.chat(("? = a wave you never answered, %d of them this pull"):format(missed))
    end
    local d = lastPull.death
    if not d then
        return
    end
    if d.phase == "echo" and d.safe == "?" then
        AZT.chat(("you died in echo %d, the one wave you never answered"):format(d.wave))
    elseif d.phase == "echo" and d.safe then
        AZT.chat(("you died in echo %d - safe was %s"):format(d.wave, AZT.QuadName(d.safe, 14)))
    elseif d.phase == "wave" then
        AZT.chat(("you died during wave %d of the channel"):format(d.wave))
    else
        AZT.chat("you died between the waves and the echoes")
    end
end

--#endregion

--#region Replay

local replayTicker

function Safe.StopReplay()
    if not replayTicker then
        return
    end
    replayTicker:Cancel()
    replayTicker = nil
    setWave(nil, 0, nil, nil)
    if AZT.SetSafeQuads then
        AZT.SetSafeQuads(seq)
    end
end

-- shared front door for both replay flavors: a second click stops the run
-- that is going, and nothing starts during the pull. Says whether the
-- caller may start a fresh run.
local function replayGate()
    if armed then
        AZT.chat("not during the pull")
        return false
    end
    if replayTicker then
        Safe.StopReplay()
        AZT.chat("replay stopped")
        return false
    end
    return true
end

-- walk a route across the room view on its real wave cadence. Display
-- only, the live capture state stays untouched.
local function runReplay(list, g)
    local startT = GetTime() + REPLAY_LEAD
    local shown = 0
    if AZT.EnsureRoomView then
        AZT.EnsureRoomView()
    end
    replayTicker = C_Timer.NewTicker(0.18, function()
        local nowT = GetTime()
        local due = 0
        if nowT >= startT then
            due = math.floor((nowT - startT) / g.spacing) + 1
        end
        if due > #list then
            if nowT >= startT + #list * g.spacing + REPLAY_TAIL then
                Safe.StopReplay()
                AZT.chat("replay done")
            end
            return
        end
        if due > shown then
            shown = due
            setWave("replay", due, #list, startT + due * g.spacing)
            if AZT.SetSafeQuads then
                AZT.SetSafeQuads(list, due)
            end
            if AZT.Cue then
                -- no landing time, so it speaks now as a real pull does
                AZT.Cue(list[due], nil, due > 1 and list[due - 1] or list[#list])
            end
        end
    end)
end

-- practice run between pulls, over what the last pull recorded
function Safe.Replay()
    if not replayGate() then
        return
    end
    if not lastPull or #lastPull.seq == 0 then
        AZT.chat("nothing recorded yet - pull the boss once first")
        return
    end
    AZT.chat(("replaying the last route (%d waves) - move along with it, or just watch"):format(#lastPull.seq))
    runReplay(lastPull.seq, lastPull.grid or grid)
end

-- three made-up waves for the settings button, so the whole echo display
-- can be watched without ever pulling the boss
local DEMO_ROUTE = { "N", "E", "W", "S" }

function Safe.PreviewReplay()
    if not replayGate() then
        return
    end
    AZT.chat("previewing three pretend waves - this is what the echoes look like")
    runReplay(DEMO_ROUTE, grid)
end

--#endregion

--#region Events

local ENCOUNTER_IDS = { [3508] = "? (normal)", [3525] = "?? (hard)" }

-- Boss casts arrive on nameplateN units only when enemy nameplates are
-- enabled. BossN frames fire regardless, so both token kinds are accepted
-- (the seen-first token wins and the chanUnit filter drops the duplicate).
local function hostileUnit(unit)
    if type(unit) ~= "string" then
        return false
    end
    if unit:match("^boss%d$") then
        return true
    end
    if not unit:match("^nameplate%d+$") then
        return false
    end
    local ok, hostile = pcall(UnitCanAttack, "player", unit)
    if not ok or (issecretvalue and issecretvalue(hostile)) then
        return false
    end
    return hostile and true or false
end

local ef = CreateFrame("Frame")
ef:RegisterEvent("ENCOUNTER_START")
ef:RegisterEvent("ENCOUNTER_END")
ef:RegisterEvent("UNIT_SPELLCAST_CHANNEL_START")
ef:RegisterEvent("UNIT_SPELLCAST_CHANNEL_STOP")
ef:RegisterEvent("UNIT_SPELLCAST_START")
ef:SetScript("OnEvent", function(_, event, ...)
    local ok, err = pcall(function(...)
        if event == "ENCOUNTER_START" then
            local id, name = ...
            if ENCOUNTER_IDS[id] or (type(name) == "string" and name:find("Azta")) then
                armed = true
                grid = GRIDS[id] or GRIDS[3508]
                Safe.Reset()
                ef:RegisterEvent("PLAYER_DEAD")
                AZT.chat(
                    ("Azta'rec pulled - encounter %s = %s"):format(
                        tostring(id),
                        ENCOUNTER_IDS[id] or "unknown difficulty"
                    )
                )
            end
        elseif event == "ENCOUNTER_END" then
            armed = false
            ef:UnregisterEvent("PLAYER_DEAD")
            -- the pull is over, wipe or kill, so clear the board rather than
            -- leave a dead run up. Review and replay keep their own copy,
            -- taken before this fires
            Safe.Reset()
        elseif event == "PLAYER_DEAD" then
            snapshotPull()
            if lastPull then
                local d = {}
                if capturing then
                    d.phase, d.wave = "wave", math.max(winIdx, 1)
                elseif echoIdx > 0 then
                    d.phase, d.wave = "echo", echoIdx
                end
                d.safe = d.wave and lastPull.seq[d.wave] or nil
                lastPull.death = d
            end
        elseif event == "UNIT_SPELLCAST_CHANNEL_START" then
            local unit = ...
            if not armed or not hostileUnit(unit) then
                return
            end
            if capturing and chanUnit and unit ~= chanUnit then
                -- only the real boss channels, so the same channel arriving on
                -- a boss token is the same unit - adopt the sturdier token
                -- (boss frames never despawn mid-encounter but nameplates can)
                if unit:match("^boss%d$") and not chanUnit:match("^boss%d$") then
                    AZT.Log("CHANNELER token upgraded " .. chanUnit .. " -> " .. unit)
                    chanUnit = unit
                else
                    -- never wipe a capture in progress for another unit's channel
                    AZT.Log("CHANNEL from " .. unit .. " ignored - capture already running")
                end
                return
            end
            beginCapture(unit)
        elseif event == "UNIT_SPELLCAST_CHANNEL_STOP" then
            local unit = ...
            if armed and hostileUnit(unit) and (not chanUnit or unit == chanUnit) then
                finishCapture()
            end
        elseif event == "UNIT_SPELLCAST_START" then
            if not armed then
                return
            end
            local unit = ...
            if not hostileUnit(unit) then
                return
            end
            local nowT = GetTime()
            -- only the channeling unit's casts are echoes. The "??" clone's
            -- concurrent casts must not consume echo slots
            if chanUnit and unit ~= chanUnit then
                return
            end
            if #seq == 0 or echoIdx >= #seq or nowT > echoUntil then
                return
            end
            if nowT - lastEchoAdvance < 1 then
                return
            end
            local gap = lastEchoAdvance > 0 and (nowT - lastEchoAdvance) or nil
            lastEchoAdvance = nowT
            echoIdx = echoIdx + 1
            -- Reading the boss cast bar is the honest countdown source: each echo is
            -- one cast by the unit that ran the channel, and its end time is the
            -- tick where the wave really lands. When the client keeps the end time
            -- hidden the display falls back to nothing rather than guessing, so
            -- it can only ever go quiet, not wrong. The recorded route itself is
            -- read-only from here on, the cast bar feeds the countdown text and
            -- reaches nothing else.
            local at
            local okC, _, _, _, _, endMS = pcall(UnitCastingInfo, unit)
            if okC and endMS then
                local okT, t = pcall(function()
                    return endMS / 1000
                end)
                if okT and type(t) == "number" then
                    at = t
                end
            end
            setWave("echo", echoIdx, #seq, at, nowT, gap)
            if AZT.SetSafeQuads then
                AZT.SetSafeQuads(seq, echoIdx)
            end
            if AZT.Cue then
                AZT.Cue(seq[echoIdx], at, echoIdx > 1 and seq[echoIdx - 1] or seq[#seq])
            end
            if echoIdx >= #seq then
                -- clear the board just after the last wave actually lands:
                -- cast end plus a beat to see the outcome, or a spacing's
                -- worth when the end time was unreadable
                local delay
                local okD, d = pcall(function()
                    return at - GetTime()
                end)
                if okD and type(d) == "number" and d > 0 and d < 10 then
                    delay = d + 2
                else
                    delay = grid.spacing + 2
                end
                C_Timer.NewTimer(delay, function()
                    Safe.Reset()
                end)
            end
        end
    end, ...)
    if not ok then
        AZT.Log("SAFE_ERR " .. tostring(event) .. ": " .. tostring(err))
    end
end)

--#endregion
