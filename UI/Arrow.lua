-- Azta'rec Helper, copyright 2026 Rothirr, all rights reserved.
-- Read it if you want. Copying any of it into another addon is theft, and
-- running it through an AI tool first does not change that. The timings and
-- coordinates were measured by hand. Nothing here is licensed to anyone.

local _, AZT = ...

-- The safe-spot arrow. Walks the recorded route through the echoes, showing
-- the move out of the quarter the last wave left you in. One colour the
-- whole way, the player's pick, since the encounter hides the moment a wave
-- lands and a colour that changes on a guess is worse than one that does
-- not change at all. It parks dimmed around the delve out of combat so it
-- can be dragged into place. In combat it only exists while the memory
-- game runs.

local arrowFrame

-- Two ways to read the arrow, and mixing them is what gives people mixed
-- signals. Relative assumes you look at the boss from your quarter, 
-- Compass drops that assumption and points the way the room view does
local TURN_RAD = { stay = math.pi, forward = 0, left = math.pi / 2, right = -math.pi / 2 }
local QUAD_ROT = { N = 0, E = -math.pi / 2, S = math.pi, W = math.pi / 2 }

-- no rgb means the art draws as it was painted, which is gold
AZT.ARROW_COLORS = {
    gold = { label = "Gold", rgb = nil },
    red = { label = "Red", rgb = { 0.95, 0.3, 0.25 } },
    green = { label = "Green", rgb = { 0.3, 0.95, 0.4 } },
    white = { label = "White", rgb = { 1, 1, 1 } },
    cyan = { label = "Cyan", rgb = { 0.35, 0.85, 1 } },
    violet = { label = "Violet", rgb = { 0.78, 0.55, 1 } },
}
AZT.ARROW_ORDER = { "gold", "red", "green", "white", "cyan", "violet" }

function AZT.ArrowColor()
    return AZT.ARROW_COLORS[AztarecHelperDB.arrowColor or "gold"] or AZT.ARROW_COLORS.gold
end

local TURN_SMOOTH = 0.18 -- fraction of the remaining turn applied per tick
local SAFE_HOLD = 1.5 -- an echo overdue by this long means the run stopped, so stop pointing
local UPDATE_HZ = 20 -- pointer refresh rate
local PARK_ALPHA = 0.8 -- parked brightness
local LABEL_LIFT = 9 -- the caption sits this many px above the frame bottom
local TURN_SNAP = 1.8 -- turns bigger than this many radians snap instead of easing
local MARK_SIZE = 44 -- the quarter's mark under the arrow

local function buildArrow()
    arrowFrame = CreateFrame("Frame", "AztarecHelperArrow", UIParent)
    arrowFrame:SetSize(96, 142)
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
    label:SetPoint("BOTTOM", 0, LABEL_LIFT)
    arrowFrame.label = label

    -- the quarter's mark sits under the arrow
    local function setMark(q)
        label:SetText(q and AZT.QuadName(q, MARK_SIZE) or "")
        label:SetTextColor(1, 1, 1, 1)
    end
    arrowFrame.setMark = setMark
    AZT.AttachLock(arrowFrame, "arrow")
    arrowFrame:Hide()

    -- the colour multiplies onto the desaturated art. Passing none leaves the
    -- art alone, which is how gold stays gold.
    local lastRot, lastAlpha, lastRGB
    local function showPointer(rot, alpha, rgb)
        -- same arrow as last tick, nothing to redraw. It earns its keep
        -- between echoes, where the arrow sits unchanged for seconds.
        if rot == lastRot and alpha == lastAlpha and rgb == lastRGB and tex:IsShown() then
            return
        end
        if not pcall(tex.SetRotation, tex, rot) then
            tex:Hide()
            lastRot = nil
            return
        end
        lastRot, lastAlpha, lastRGB = rot, alpha, rgb
        tex:SetDesaturated(rgb and true or false)
        if rgb then
            tex:SetVertexColor(rgb[1], rgb[2], rgb[3], alpha)
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

    -- ease toward a new direction so 90 degree corrections glide, but snap
    -- through about-faces since an eased 180 reads as lag
    local function easeTo(rot)
        local delta = (rot - shownRot + math.pi) % (2 * math.pi) - math.pi
        if math.abs(delta) > TURN_SNAP then
            shownRot = rot
        else
            shownRot = shownRot + delta * TURN_SMOOTH
        end
        return shownRot
    end

    local elapsed = 0
    arrowFrame:SetScript("OnUpdate", function(_, dt)
        elapsed = elapsed + dt
        if elapsed < 1 / UPDATE_HZ then
            return
        end
        elapsed = 0
        local w = AZT.Wave
        if w and w.phase == "record" then
            -- nothing to call during the Sermon, so it points at your feet.
            showPointer(easeTo(math.pi), 1, AZT.ArrowColor().rgb)
            setMark(nil)
            return
        end
        local safeNow = AZT.safeNow
        if not safeNow then
            return -- parked, ArrowSync painted the waiting state already
        end
        local list = AZT.safeList
        local blank = not (w and (w.phase == "echo" or w.phase == "replay") and w.idx > 0 and list)
        -- an echo this far overdue means the run stopped, so stop pointing
        -- instead of holding a call nothing is coming for
        if not blank and w.gap and w.startedAt then
            local okG, since = pcall(function()
                return GetTime() - w.startedAt
            end)
            blank = okG and type(since) == "number" and since > w.gap + SAFE_HOLD
        end
        if blank then
            hidePointer()
            setMark(safeNow)
            return
        end
        local compass = AztarecHelperDB.arrowCompass
        local rot
        if compass then
            rot = QUAD_ROT[safeNow]
        else
            -- the move out of the quarter the last wave left you in. It
            -- trusts the recording, so a player who fell behind gets
            -- pointed from where they should be standing.
            local prevQ = w.idx > 1 and list[w.idx - 1] or list[#list]
            local turn = AZT.Safe.TurnFromTo(prevQ, safeNow)
            rot = turn and TURN_RAD[turn]
        end
        setMark(safeNow)
        if rot then
            showPointer(easeTo(rot), 1, AZT.ArrowColor().rgb)
        else
            -- an unknown step in the route, nothing honest to point at
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
    -- while recording the update loop owns the arrow, so leave it alone
    if on and not live and not recording then
        -- the colour you picked, dimmed. Parking it in grey would hide the
        -- one thing you are looking at while choosing one.
        arrowFrame.showPointer(0, PARK_ALPHA, AZT.ArrowColor().rgb)
        -- the caption helps placement and names the reading you are on
        arrowFrame.setMark(nil)
        local mode = AztarecHelperDB.arrowCompass and "compass arrow" or "relative arrow"
        arrowFrame.label:SetText(fighting and "" or mode)
        arrowFrame.label:SetTextColor(1, 1, 1, 0.5)
    end
end
