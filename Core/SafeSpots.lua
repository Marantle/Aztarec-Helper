-- Azta'rec Helper, copyright 2026 Rothirr, all rights reserved.
-- Read it if you want. Copying any of it into another addon is theft, and
-- running it through an AI tool first does not change that. The timings and
-- coordinates were measured by hand. Nothing here is licensed to anyone.

local _, AZT = ...

-- Auto safe-spot tracking for the Azta'rec wave mechanic. While the boss
-- channels, the player's quadrant is sampled continuously and each wave takes
-- the majority quadrant around its measured hit time. When the hidden echoes
-- start right after the channel, each cast start calls out where to stand.

local Safe = {}
AZT.Safe = Safe

BINDING_HEADER_AZTARECHELPER = "Azta'rec Helper"
BINDING_NAME_AZTARECHELPER_CAPTURE = "Capture safe spot (manual override)"

local seq = {}
local armed = false

-- auto-capture state
local sampler
local winIdx = 0
local chanStartT = 0
-- per-difficulty cone hit grids (offsets after CHAN_START), measured via
-- deliberate deaths on the PTR. Both difficulties end the channel ~0.5s
-- after the last hit. Wave count grows per channel, so waves keep locking
-- until the channel actually stops.
local GRIDS = {
    [3508] = { first = 3.04, spacing = 3.5 }, -- "?"
    [3525] = { first = 2.50, spacing = 3.01 }, -- "??"
}
local grid = GRIDS[3508]
local MAX_WAVES = 10
local VOTE_HALF = 0.7 -- majority vote over hit +/- this many seconds
local LOCK_DELAY = 0.7 -- lock the spot this long after the hit
local samples = {} -- { t = seconds since CHAN_START, q = quadrant }
local manualWin = {} -- windows overridden by the capture key
local chanUnit = nil -- unit token that ran the channel, its casts are the echoes
local capturing = false -- a channel is being recorded (auto sampler or manual)
local lastCapture = 0 -- Capture() throttle so a double-tap can't append twice
local shaky = {} -- waves voted without a clear majority (player was crossing quadrants)
local lastPull -- most recent recorded route, kept for review and replay

local CONF_SHARE = 0.8 -- a winning quadrant below this share of its vote window is marked uncertain
local REPLAY_LEAD = 1.8 -- pause before a replay's first wave
local REPLAY_TAIL = 1.8 -- how long the last replay wave stays lit

-- what the wave countdown renders. One table, fields overwritten in place.
local wave = { phase = nil, idx = 0, total = nil, at = nil }
AZT.Wave = wave

local function setWave(phase, idx, total, at)
    wave.phase, wave.idx, wave.total, wave.at = phase, idx, total, at
    if AZT.WaveSync then
        AZT.WaveSync()
    end
    if AZT.ArrowSync then
        AZT.ArrowSync()
    end
end

local function hitTime(i)
    return grid.first + grid.spacing * (i - 1)
end

-- channel duration = first + (n-1)*spacing + ~0.46 trail on every measured
-- pull, so the duration alone identifies the grid: how far is the measured
-- length from this grid's nearest whole-wave length?
local GRID_LIST = { GRIDS[3508], GRIDS[3525] }
local function gridFitError(g, elapsed)
    local n = math.floor((elapsed - 0.46 - g.first) / g.spacing + 0.5) + 1
    if n < 1 then
        n = 1
    end
    return math.abs(g.first + (n - 1) * g.spacing + 0.46 - elapsed)
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

-- Which quadrant a room-local offset falls in. Shared with the room view so
-- both bucket the same way.
function Safe.QuadrantFromXY(x, y)
    -- compass angle: 0 = north, 90 = east
    local ang = math.deg(math.atan2(x, y))
    if ang < 0 then
        ang = ang + 360
    end
    return QUADRANTS[math.floor(((ang + 45) % 360) / 90) + 1]
end

-- Which quadrant the player stands in, relative to the room center.
function Safe.CurrentQuadrant()
    local ok, a, b = pcall(UnitPosition, "player")
    if not ok or not a or not b then
        return nil
    end
    local R = AZT.ROOM
    local okC, x, y = pcall(function()
        return R.centerB - b, a - R.centerA
    end)
    if not okC then
        return nil
    end
    return Safe.QuadrantFromXY(x, y), x, y
end

--#region Capture

function Safe.StopSampler()
    if sampler then
        sampler:Cancel()
        sampler = nil
    end
end

-- majority quadrant around a wave hit. Ties go to the most recently occupied.
-- Also says how sure the vote was: a winner that only scraped by (player was
-- mid-run between quadrants) gets flagged, and the display marks it.
local function voteQuadrant(hitT)
    local from, to = hitT - VOTE_HALF, hitT + VOTE_HALF
    local counts, lastAt = {}, {}
    local total = 0
    for _, s in ipairs(samples) do
        if s.q and s.t >= from and s.t <= to then
            counts[s.q] = (counts[s.q] or 0) + 1
            lastAt[s.q] = s.t
            total = total + 1
        end
    end
    local best
    for q in pairs(counts) do
        if not best or counts[q] > counts[best] or (counts[q] == counts[best] and lastAt[q] > lastAt[best]) then
            best = q
        end
    end
    local sure = best ~= nil and total >= 3 and counts[best] / total >= CONF_SHARE
    return best, sure
end

local function lockWindow(i, early)
    if manualWin[i] then
        return
    end
    local q, sure = voteQuadrant(hitTime(i))
    seq[i] = q or Safe.CurrentQuadrant() or "?"
    shaky[i] = (not (q and sure)) or nil
    AZT.Log(("AUTOSPOT %d = %s%s%s"):format(i, seq[i], shaky[i] and " (shaky)" or "", early and " (early)" or ""))
end

local function beginCapture(unit)
    Safe.StopSampler()
    wipe(seq)
    wipe(samples)
    wipe(manualWin)
    wipe(shaky)
    chanUnit = unit
    chanStartT = GetTime()
    capturing = true
    if AZT.SetSafeQuads then
        AZT.SetSafeQuads(seq)
    end
end

-- keep a copy of the route for review and replay, since the live tables get
-- wiped the moment the next channel starts
local function snapshotPull()
    if #seq == 0 then
        return
    end
    lastPull = { seq = {}, shaky = {}, grid = grid, death = nil }
    for i, q in ipairs(seq) do
        lastPull.seq[i] = q
        lastPull.shaky[i] = shaky[i]
    end
end

-- manual mode: the channel only marks when recording is open. Every spot
-- comes from the capture key
local function beginManualCapture(unit)
    beginCapture(unit)
    winIdx = 0
    AZT.Log("MANUAL capture open - waiting for capture key presses")
end

local function beginAutoCapture(unit)
    beginCapture(unit)
    winIdx = 1
    -- the sampler runs until CHAN_STOP: the wave count is not known up front
    sampler = C_Timer.NewTicker(0.2, function()
        if winIdx > MAX_WAVES then
            return
        end
        local elapsed = GetTime() - chanStartT
        samples[#samples + 1] = { t = elapsed, q = Safe.CurrentQuadrant() }
        setWave("record", winIdx, nil, chanStartT + hitTime(winIdx))
        if elapsed >= hitTime(winIdx) + LOCK_DELAY then
            lockWindow(winIdx)
            winIdx = winIdx + 1
            if AZT.SetSafeQuads then
                AZT.SetSafeQuads(seq, nil, shaky)
            end
        end
    end)
end

local function finishAutoCapture()
    local wasManual = capturing and not sampler and chanUnit ~= nil
    capturing = false
    if wasManual then
        AZT.Log(("MANUAL capture closed on channel stop: %s"):format(seqText()))
    end
    if sampler then
        Safe.StopSampler()
        local elapsed = GetTime() - chanStartT
        if elapsed < 8 then
            -- real wave channels run 10.5s or longer. Something shorter slipped
            -- through the filters (or the boss died) - discard, don't replay
            AZT.Log(("CHANNEL discarded after %.1fs - not the wave mechanic"):format(elapsed))
            Safe.Reset()
            return
        end
        -- fallback for renumbered encounter ids / retuned timings: if the
        -- measured channel length doesn't fit the id-selected grid, re-fit
        -- against all known grids and re-vote every wave from the stored
        -- samples (they cover the whole channel, so nothing is lost)
        if gridFitError(grid, elapsed) > 0.3 then
            local best, bestErr
            for _, g in ipairs(GRID_LIST) do
                local e = gridFitError(g, elapsed)
                if not bestErr or e < bestErr then
                    best, bestErr = g, e
                end
            end
            if best ~= grid and bestErr <= 0.3 then
                grid = best
                AZT.Log(("GRID re-fit from %.2fs channel (err %.2fs) - re-voting all waves"):format(elapsed, bestErr))
                wipe(seq)
                wipe(manualWin)
                wipe(shaky)
                winIdx = 1
            else
                AZT.Log(
                    ("GRID warning: %.2fs channel fits no known wave grid (best err %.2fs)"):format(elapsed, bestErr)
                )
            end
        end
        -- lock any wave whose hit already landed but wasn't locked yet
        -- (the last hit comes ~0.5s before CHAN_STOP)
        while winIdx <= MAX_WAVES and hitTime(winIdx) <= elapsed + 0.6 do
            lockWindow(winIdx, true)
            winIdx = winIdx + 1
        end
        AZT.Log(("AUTOSPOT finalized on channel stop after %.1fs: %s"):format(elapsed, seqText()))
    end
    if AZT.SetSafeQuads then
        AZT.SetSafeQuads(seq, nil, shaky)
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

-- capture key: overrides the current auto window during an auto-recorded
-- channel, otherwise appends (manual mode, or fallback if the channel isn't
-- detected). Throttled so a double-tap can't write two waves.
function Safe.Capture()
    local nowT = GetTime()
    if nowT - lastCapture < 0.5 then
        return
    end
    lastCapture = nowT
    local q, x, y = Safe.CurrentQuadrant()
    if not q then
        AZT.chat("capture failed - position unavailable")
        return
    end
    if sampler and winIdx >= 1 and winIdx <= MAX_WAVES then
        seq[winIdx] = q
        manualWin[winIdx] = true
        shaky[winIdx] = nil
        AZT.Log(("SAFESPOT manual override %d = %s"):format(winIdx, q))
        AZT.chat(("manual override: spot %d = %s"):format(winIdx, q))
        return
    end
    if #seq >= MAX_WAVES then
        wipe(seq)
        wipe(shaky)
    end
    seq[#seq + 1] = q
    AZT.Log(("SAFESPOT %d = %s (x=%.1f y=%.1f)"):format(#seq, q, x, y))
    if AZT.SetSafeQuads then
        AZT.SetSafeQuads(seq, nil, shaky)
    end
    AZT.chat(("safe spot %d captured: %s"):format(#seq, q))
end

-- global for Bindings.xml
function AztarecHelper_Capture()
    Safe.Capture()
end

function Safe.Reset()
    Safe.StopSampler()
    Safe.StopReplay()
    wipe(seq)
    wipe(samples)
    wipe(manualWin)
    wipe(shaky)
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

function Safe.IsShaky(i)
    return shaky[i]
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
    local parts, doubts = {}, 0
    for i, q in ipairs(lastPull.seq) do
        if lastPull.shaky[i] then
            parts[i] = q .. "?"
            doubts = doubts + 1
        else
            parts[i] = q
        end
    end
    AZT.chat("last pull: " .. table.concat(parts, "  >  "))
    if doubts > 0 then
        AZT.chat("? = recorded while you were crossing quadrants, trust those less")
    end
    local d = lastPull.death
    if not d then
        return
    end
    if d.phase == "echo" and d.safe then
        local stood = d.stood and (", you were " .. d.stood) or ""
        AZT.chat(("you died in echo %d - safe was %s%s"):format(d.wave, d.safe, stood))
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
        AZT.SetSafeQuads(seq, nil, shaky)
    end
end

-- Practice run between pulls: walk the last recorded route across the room
-- view on its real wave cadence. Display only, the live capture state stays
-- untouched, and pulling the boss cancels it.
function Safe.Replay()
    if armed then
        AZT.chat("not during the pull")
        return
    end
    if replayTicker then
        Safe.StopReplay()
        AZT.chat("replay stopped")
        return
    end
    if not lastPull or #lastPull.seq == 0 then
        AZT.chat("nothing recorded yet - pull the boss once first")
        return
    end
    local g = lastPull.grid or grid
    local list, marks = lastPull.seq, lastPull.shaky
    local startT = GetTime() + REPLAY_LEAD
    local shown = 0
    if AZT.EnsureRoomView then
        AZT.EnsureRoomView()
    end
    AZT.chat(("replaying the last route (%d waves) - move along with it, or just watch"):format(#list))
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
                AZT.SetSafeQuads(list, due, marks)
            end
        end
    end)
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
            Safe.StopSampler()
            ef:UnregisterEvent("PLAYER_DEAD")
            setWave(nil, 0, nil, nil)
            -- drop the live call so the arrow stops pointing. The recorded
            -- route stays on the room view
            if AZT.SetSafeQuads then
                AZT.SetSafeQuads(seq, nil, shaky)
            end
        elseif event == "PLAYER_DEAD" then
            snapshotPull()
            if lastPull then
                local d = { stood = Safe.CurrentQuadrant() }
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
            if AztarecHelperDB.manualMode then
                beginManualCapture(unit)
            else
                beginAutoCapture(unit)
            end
        elseif event == "UNIT_SPELLCAST_CHANNEL_STOP" then
            local unit = ...
            if armed and hostileUnit(unit) and (not chanUnit or unit == chanUnit) then
                finishAutoCapture()
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
            setWave("echo", echoIdx, #seq, at)
            if AZT.SetSafeQuads then
                AZT.SetSafeQuads(seq, echoIdx, shaky)
            end
            if echoIdx >= #seq then
                -- clear the radar just after the last wave actually lands:
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
