-- Azta'rec Helper, copyright 2026 Rothirr, all rights reserved.
-- Read it if you want. Copying any of it into another addon is theft, and
-- running it through an AI tool first does not change that. The timings and
-- coordinates were measured by hand. Nothing here is licensed to anyone.

local _, AZT = ...

-- Shared plumbing for the floating windows.

--#region Locks
-- Each floating window carries a padlock in its corner. A locked window
-- can't be dragged and lets clicks pass through it. Only the padlock itself,
-- the room view's buttons and the quarter icon menus still take the mouse.
-- While locked the padlock hides until the cursor crosses it.

local lockApply = {}

local function locks()
    AztarecHelperDB.locks = AztarecHelperDB.locks or {}
    return AztarecHelperDB.locks
end

function AZT.AttachLock(frame, key, alsoUnclick, ox, oy)
    local btn = CreateFrame("Button", nil, frame)
    btn:SetSize(16, 16)
    btn:SetPoint("TOPRIGHT", ox or -3, oy or -3)
    btn:SetNormalTexture("Interface\\AddOns\\AztarecHelper\\Media\\lock")
    btn:SetHighlightTexture("Interface\\AddOns\\AztarecHelper\\Media\\lock", "ADD")

    local function apply()
        local locked = locks()[key] and true or false
        frame:EnableMouse(not locked)
        for _, f in ipairs(alsoUnclick or {}) do
            f:EnableMouse(not locked)
        end
        btn:SetAlpha(locked and 0 or 0.85)
    end
    btn:SetScript("OnClick", function()
        locks()[key] = not locks()[key] or nil
        apply()
        btn:SetAlpha(1) -- the cursor is still on it so keep it readable
    end)
    btn:SetScript("OnEnter", function()
        btn:SetAlpha(1)
    end)
    btn:SetScript("OnLeave", function()
        btn:SetAlpha(locks()[key] and 0 or 0.85)
    end)
    lockApply[key] = apply
    apply()
end

function AZT.GetWindowLock(key)
    return locks()[key] and true or false
end

function AZT.SetWindowLock(key, v)
    locks()[key] = v and true or nil
    if lockApply[key] then
        lockApply[key]()
    end
end
--#endregion

--#region Dragging

-- shared drag wiring for the small floating windows
function AZT.MakeMovable(frame, posKey, defPoint, defX, defY)
    local pos = AztarecHelperDB[posKey]
    if pos and pos.point then
        frame:SetPoint(pos.point, UIParent, pos.relPoint or pos.point, pos.x or 0, pos.y or 0)
    else
        frame:SetPoint(defPoint, UIParent, defPoint, defX, defY)
    end
    frame:SetFrameStrata("MEDIUM")
    frame:SetMovable(true)
    frame:SetClampedToScreen(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", function(f)
        f:StopMovingOrSizing()
        local point, _, relPoint, x, y = f:GetPoint(1)
        AztarecHelperDB[posKey] = { point = point, relPoint = relPoint, x = x, y = y }
    end)
end
--#endregion
