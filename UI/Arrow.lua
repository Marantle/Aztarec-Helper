local _, AZT = ...

-- The safe-spot arrow. Points from where you stand to the called safe
-- quadrant. Red on the way in, green once you stand right (then it aims
-- ahead at the next call), grey around the delve out of combat so it can
-- be dragged into place. In combat it only exists while the memory game
-- runs.

local arrowFrame
local QUAD_RAD = { N = 0, E = math.rad(90), S = math.rad(180), W = math.rad(270) }
local REACH = AZT.ROOM.radius * 0.6 -- aim point: the quarter's center of area

local function bearing(facing, dx, dy)
    return -(facing + math.atan2(dx, dy))
end

local function readFacing()
    local ok, facing = pcall(GetPlayerFacing)
    if ok and type(facing) == "number" then
        return facing
    end
end

local TURN_SMOOTH = 0.18 -- fraction of the remaining turn applied per tick
local SAFE_HOLD = 1.5 -- ride out unreadable-position blips this long before blanking
local UPDATE_HZ = 20 -- pointer refresh rate
local PARK_ALPHA = 0.8 -- parked brightness
local NEAR_YD = 9 -- the distance label brightens inside this range
local TURN_SNAP = 1.8 -- turns bigger than this many radians snap instead of easing

local function buildArrow()
    arrowFrame = CreateFrame("Frame", "AztarecHelperArrow", UIParent)
    arrowFrame:SetSize(96, 124)
    AZT.MakeMovable(arrowFrame, "arrowPos", "TOP", 0, -100)

    -- our own arrow art. Blizzard's guide arrow blp turned out to carry
    -- baked-in translucency no blend mode gets around, so this ships as a
    -- proper opaque texture instead
    local tex = arrowFrame:CreateTexture(nil, "ARTWORK")
    tex:SetSize(88, 88)
    tex:SetPoint("TOP", 0, -18)
    tex:SetTexture("Interface\\AddOns\\AztarecHelper\\Media\\arrow")
    tex:Hide()

    local label = arrowFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    label:SetPoint("BOTTOM")
    arrowFrame.label = label
    AZT.AttachLock(arrowFrame, "arrow")
    arrowFrame:Hide()

    -- color multiplied onto the desaturated art per state. No entry means no
    -- tint and the art shows gold as drawn.
    local TINT = {
        idle = { 0.6, 0.6, 0.6 },
        safe = { 0.3, 0.95, 0.4 },
        go = { 0.95, 0.3, 0.25 },
    }
    local lastRot, lastAlpha, lastTint
    local function showPointer(rot, alpha, tint)
        -- same arrow as last tick, nothing to redraw. Mostly earns its keep
        -- in the safe state, where the arrow can sit unchanged for seconds.
        if rot == lastRot and alpha == lastAlpha and tint == lastTint and tex:IsShown() then
            return
        end
        if not pcall(tex.SetRotation, tex, rot) then
            tex:Hide()
            lastRot = nil
            return
        end
        lastRot, lastAlpha, lastTint = rot, alpha, tint
        tex:SetDesaturated(tint and true or false)
        local c = tint and TINT[tint]
        if c then
            tex:SetVertexColor(c[1], c[2], c[3], alpha)
        else
            tex:SetVertexColor(1, 1, 1, alpha)
        end
        tex:Show()
    end
    local function hidePointer()
        tex:Hide()
        lastRot = nil
    end
    arrowFrame.showPointer = showPointer

    local shownRot = 0
    local lastReadAt = 0

    -- ease toward a new bearing so small corrections glide, but snap through
    -- big ones since an eased about-face reads as lag
    local function easeTo(rot)
        local delta = (rot - shownRot + math.pi) % (2 * math.pi) - math.pi
        if math.abs(delta) > TURN_SNAP then
            shownRot = rot
        else
            shownRot = shownRot + delta * TURN_SMOOTH
        end
        return shownRot
    end

    -- bearing and distance from the player to the quadrant's center of area,
    -- which for a quarter slice sits about six tenths of the way out along
    -- its middle line. Facing can go secret in combat if Blizzard nerfs
    -- this, then rot comes back nil and the name and distance still help.
    local function aim(quad, x, y, facing)
        local rad = QUAD_RAD[quad] or 0
        local dx, dy = math.sin(rad) * REACH - x, math.cos(rad) * REACH - y
        local dist = math.sqrt(dx * dx + dy * dy)
        if facing == nil then
            return nil, dist
        end
        local okR, rot = pcall(bearing, facing, dx, dy)
        if okR and type(rot) == "number" then
            return rot, dist
        end
        return nil, dist
    end

    local elapsed = 0
    arrowFrame:SetScript("OnUpdate", function(_, dt)
        elapsed = elapsed + dt
        if elapsed < 1 / UPDATE_HZ then
            return
        end
        elapsed = 0
        local safeNow, nextNow = AZT.safeNow, AZT.nextNow
        if not safeNow then
            return -- parked, ArrowSync painted the waiting state already
        end
        local q, x, y = AZT.Safe.CurrentQuadrant()
        if not x then
            -- position reads drop out for a moment now and then, so the last
            -- verdict stays up briefly
            if GetTime() - lastReadAt > SAFE_HOLD then
                hidePointer()
                label:SetText(safeNow)
                label:SetTextColor(1, 1, 1)
            end
            return
        end
        lastReadAt = GetTime()

        if q == safeNow then
            -- standing right: green, pointing ahead at the next quarter so
            -- the move can start the moment the wave resolves. With no next
            -- call it points straight down because you are the destination.
            label:SetTextColor(0.4, 1, 0.5)
            label:SetText(AZT.stayText)
            local rot
            if nextNow and nextNow ~= safeNow then
                rot = aim(nextNow, x, y, readFacing())
            end
            if rot then
                showPointer(easeTo(rot), 1, "safe")
            else
                shownRot = math.pi
                showPointer(math.pi, 1, "safe")
            end
            return
        end

        -- standing wrong: red, pointing at the safe quarter
        local rot, dist = aim(safeNow, x, y, readFacing())
        label:SetText(("%s  %.0f yd"):format(safeNow, dist))
        if dist < NEAR_YD then
            label:SetTextColor(1, 0.6, 0.5)
        else
            label:SetTextColor(0.95, 0.4, 0.35)
        end
        if rot then
            showPointer(easeTo(rot), 1, "go")
        else
            hidePointer()
        end
    end)
end

function AZT.ArrowSync()
    local live = AZT.safeNow ~= nil
    local recording = AZT.Wave and AZT.Wave.phase == "record"
    -- grey and grabbable around the delve out of combat. Once anything says
    -- a fight is on (regen flag, lockdown API, armed encounter) it only
    -- exists while the memory game itself is running.
    local fighting = AZT.inCombat or InCombatLockdown() or (AZT.Safe and AZT.Safe.IsArmed and AZT.Safe.IsArmed())
    local idleParked = AZT.InDelve() and not fighting
    local on = AztarecHelperDB.arrow and (live or recording or idleParked or AZT.placeMode)
    if not arrowFrame then
        if not on then
            return
        end
        buildArrow()
    end
    arrowFrame:SetShown(on and true or false)
    if on and not live then
        arrowFrame.showPointer(0, PARK_ALPHA, "idle")
        -- the caption helps placement and goes away mid-fight
        arrowFrame.label:SetText(fighting and "" or "safe-spot arrow")
        arrowFrame.label:SetTextColor(1, 1, 1, 0.5)
    end
end
