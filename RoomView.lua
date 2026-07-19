local _, AZT = ...

-- Display half of the addon: the top-down room view, the floating wave
-- countdown, the safe-spot arrow and the padlocks that keep them in place.
-- The room view follows the delve automatically for as long as the player
-- wants it around. /azt room and the options panel decide that.

local SIZE = 300 -- canvas px, covers 2 * (radius + pad) yards
local GRID_ROT = math.rad(45) -- the quarter grid sits turned so boundaries hit the diagonals

local VIEW_MODES = { "static", "rotate", "player" }
local VIEW_MODE_LABEL = { static = "North up", rotate = "Facing up", player = "Centered" }

local view
local safeNow -- quadrant the current echo calls safe; the wave text reads it
local nextNow -- the one after it, so the arrow can point ahead once you are safe
local stayText -- prebuilt safe-state label, rebuilt only when the call changes

--#region Locks
-- Each floating window carries a padlock in its corner. A locked window
-- can't be dragged and lets clicks pass through it, only the padlock itself
-- (and the room view's opts button) still takes the mouse. While locked the
-- padlock hides until the cursor crosses it.

local lockApply = {}

local function locks()
    AztarecHelperDB.locks = AztarecHelperDB.locks or {}
    return AztarecHelperDB.locks
end

local function attachLock(frame, key, alsoUnclick, ox, oy)
    local btn = CreateFrame("Button", nil, frame)
    btn:SetSize(16, 16)
    btn:SetPoint("TOPRIGHT", ox or -3, oy or -3)
    btn:SetNormalTexture("Interface\\AddOns\\AztarecHelper\\lock")
    btn:SetHighlightTexture("Interface\\AddOns\\AztarecHelper\\lock", "ADD")

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
        btn:SetAlpha(1) -- the cursor is still on it, keep it readable
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

local function build()
    local ROOM = AZT.ROOM
    local ppy = SIZE / (2 * (ROOM.radius + ROOM.pad)) -- pixels per yard

    view = CreateFrame("Frame", "AztarecHelperRoomView", UIParent, "BackdropTemplate")
    view:SetSize(SIZE + 24, SIZE + 46)
    local pos = AztarecHelperDB.roomPos
    if pos and pos.point then
        view:SetPoint(pos.point, UIParent, pos.relPoint or pos.point, pos.x or 0, pos.y or 0)
    else
        view:SetPoint("RIGHT", UIParent, "RIGHT", -60, 0)
    end
    view:SetFrameStrata("MEDIUM")
    view:SetBackdrop({
        bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true,
        tileSize = 16,
        edgeSize = 12,
        insets = { left = 3, right = 3, top = 3, bottom = 3 },
    })
    view:SetBackdropColor(0, 0, 0, 0.75)
    view:SetMovable(true)
    view:EnableMouse(true)
    view:RegisterForDrag("LeftButton")
    view:SetScript("OnDragStart", view.StartMoving)
    view:SetScript("OnDragStop", function(f)
        f:StopMovingOrSizing()
        local point, _, relPoint, x, y = f:GetPoint(1)
        AztarecHelperDB.roomPos = { point = point, relPoint = relPoint, x = x, y = y }
    end)
    view:Hide()

    local title = view:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    title:SetPoint("TOP", 0, -8)
    title:SetText("Azta'rec Helper addon")

    local optBtn = CreateFrame("Button", nil, view, "UIPanelButtonTemplate")
    optBtn:SetSize(44, 18)
    optBtn:SetPoint("TOPLEFT", 6, -4)
    optBtn:SetText("Opts")
    optBtn:SetScript("OnClick", function()
        AZT.OpenOptions()
    end)

    local helpBtn = CreateFrame("Button", nil, view)
    helpBtn:SetSize(18, 18)
    helpBtn:SetPoint("TOPRIGHT", -6, -4)
    local helpMark = helpBtn:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    helpMark:SetPoint("CENTER")
    helpMark:SetText("|cffffd200?|r")
    helpBtn:SetScript("OnEnter", function(btn)
        GameTooltip:SetOwner(btn, "ANCHOR_TOPRIGHT")
        GameTooltip:AddLine("Azta'rec Helper")
        GameTooltip:AddLine(
            "Stand in the safe quarter while the wave markers are visible. The route records itself.",
            1,
            1,
            1,
            true
        )
        GameTooltip:AddLine(
            "When the boss repeats the waves without markers, green is safe now, yellow is safe next, red gets hit.",
            1,
            1,
            1,
            true
        )
        GameTooltip:AddLine(" ")
        GameTooltip:AddDoubleLine("/azt room", "show or hide this window", 1, 0.82, 0, 1, 1, 1)
        GameTooltip:AddDoubleLine("/azt spin", "north up, facing up, or centered on you", 1, 0.82, 0, 1, 1, 1)
        GameTooltip:AddDoubleLine("/azt map", "map backdrop on or off", 1, 0.82, 0, 1, 1, 1)
        GameTooltip:AddDoubleLine("/azt cap", "record your quarter by hand (bindable key)", 1, 0.82, 0, 1, 1, 1)
        GameTooltip:AddDoubleLine("/azt manual", "record every spot yourself, no auto recording", 1, 0.82, 0, 1, 1, 1)
        GameTooltip:AddDoubleLine("/azt reset", "clear the recorded route", 1, 0.82, 0, 1, 1, 1)
        GameTooltip:AddLine(" ")
        GameTooltip:AddLine("Drag the window to move it.", 0.7, 0.7, 0.7)
        GameTooltip:Show()
    end)
    helpBtn:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)

    local canvas = CreateFrame("Frame", nil, view)
    canvas:SetSize(SIZE, SIZE)
    canvas:SetPoint("BOTTOM", 0, 22)
    canvas:SetClipsChildren(true)
    view.canvas = canvas
    view.ppy = ppy

    -- refresh the world->map rect from the client's own transform when it is
    -- readable. The measured constants in AZT.ROOM stay as fallback, so a
    -- re-measured or renumbered map self-corrects
    do
        local ok0, _, tl = pcall(C_Map.GetWorldPosFromMapPos, ROOM.uiMapID, CreateVector2D(0, 0))
        local ok1, _, br = pcall(C_Map.GetWorldPosFromMapPos, ROOM.uiMapID, CreateVector2D(1, 1))
        if ok0 and ok1 and tl and br then
            local okXY, oA, oB, sA, sB = pcall(function()
                local tA, tB = tl:GetXY()
                local bA, bB = br:GetXY()
                return tA, tB, tA - bA, tB - bB
            end)
            if okXY and type(sA) == "number" and sA > 0 and type(sB) == "number" and sB > 0 then
                ROOM.mapOriginA, ROOM.mapOriginB = oA, oB
                ROOM.mapSpanA, ROOM.mapSpanB = sA, sB
            end
        end
    end

    -- map art backdrop: Blizzard's own tiles for uiMap 2634, drawn at radar
    -- scale and aligned via the measured world->map rect in AZT.ROOM. Tiles
    -- outside the canvas are cut by the clip. /azt map toggles them.
    local artTiles = {}
    do
        local okL, layers = pcall(C_Map.GetMapArtLayers, ROOM.uiMapID)
        local layer = okL and type(layers) == "table" and layers[1] or nil
        local okT, ids
        if layer then
            okT, ids = pcall(C_Map.GetMapArtLayerTextures, ROOM.uiMapID, 1)
        end
        if layer and okT and type(ids) == "table" and #ids > 0 then
            local cols = math.ceil(layer.layerWidth / layer.tileWidth)
            -- art px per yard is layerWidth/mapSpanB horizontally and
            -- layerHeight/mapSpanA vertically (identical on this map)
            local k = ppy * ROOM.mapSpanB / layer.layerWidth
            local cx = (ROOM.mapOriginB - ROOM.centerB) / ROOM.mapSpanB * layer.layerWidth
            local cy = (ROOM.mapOriginA - ROOM.centerA) / ROOM.mapSpanA * layer.layerHeight
            for i, fdid in ipairs(ids) do
                local col, row = (i - 1) % cols, math.floor((i - 1) / cols)
                local t = canvas:CreateTexture(nil, "BACKGROUND")
                t:SetTexture(fdid)
                t:SetSize(layer.tileWidth * k, layer.tileHeight * k)
                t:SetVertexColor(0.75, 0.75, 0.75, 0.9)
                t:SetShown(AztarecHelperDB.mapArt)
                -- tile center offset from room center, canvas px (y up)
                artTiles[#artTiles + 1] = {
                    tex = t,
                    dx = ((col + 0.5) * layer.tileWidth - cx) * k,
                    dy = (cy - (row + 0.5) * layer.tileHeight) * k,
                }
            end
        end
    end
    view.artTiles = artTiles

    -- room floor, nearly transparent while the map art shows through it
    local disc = canvas:CreateTexture(nil, "ARTWORK")
    local d = 2 * ROOM.radius * ppy
    disc:SetSize(d, d)
    disc:SetPoint("CENTER")
    disc:SetTexture("Interface\\CharacterFrame\\TempPortraitAlphaMask")
    disc:SetVertexColor(0.25, 0.45, 0.70, AztarecHelperDB.mapArt and #artTiles > 0 and 0.15 or 0.40)
    view.disc = disc

    -- quadrant boundary lines through the center
    local ns = canvas:CreateTexture(nil, "ARTWORK", nil, 1)
    ns:SetColorTexture(1, 1, 1, 0.25)
    ns:SetSize(2, d)
    ns:SetPoint("CENTER")
    local ew = canvas:CreateTexture(nil, "ARTWORK", nil, 1)
    ew:SetColorTexture(1, 1, 1, 0.25)
    ew:SetSize(d, 2)
    ew:SetPoint("CENTER")

    -- quadrant wedges + labels. The slices are cut from the mask's corners,
    -- so unrotated they aim at the diagonals. The whole set draws turned 45
    -- degrees, which centers each one on its cardinal name and puts the
    -- boundaries where they belong, on the diagonals.
    local QUADS = {
        { name = "W", dx = -1, dy = 1, tc = { 0, 0.5, 0, 0.5 }, shade = 0.10 },
        { name = "N", dx = 1, dy = 1, tc = { 0.5, 1, 0, 0.5 }, shade = 0 },
        { name = "E", dx = 1, dy = -1, tc = { 0.5, 1, 0.5, 1 }, shade = 0.10 },
        { name = "S", dx = -1, dy = -1, tc = { 0, 0.5, 0.5, 1 }, shade = 0 },
    }
    local rp = ROOM.radius * ppy
    local wedges, qlabels = {}, {}
    for i, q in ipairs(QUADS) do
        local w = canvas:CreateTexture(nil, "ARTWORK", nil, 3)
        w:SetTexture("Interface\\CharacterFrame\\TempPortraitAlphaMask")
        w:SetTexCoord(unpack(q.tc))
        w:SetSize(rp, rp)
        w:SetVertexColor(1, 1, 1, q.shade)
        wedges[i] = w
        local fs = canvas:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        fs:SetTextColor(1, 1, 1, 0.65)
        qlabels[i] = fs
    end

    -- center marker (boss mechanic spot)
    local center = canvas:CreateTexture(nil, "ARTWORK", nil, 2)
    center:SetSize(6, 6)
    center:SetPoint("CENTER")
    center:SetColorTexture(1, 0.35, 0.35, 0.9)

    -- compass letters, repositioned when the view rotates with facing
    local compass = {}
    local edge = SIZE / 2 - 8
    for _, c in ipairs({ { "N", 0, 1 }, { "E", 1, 0 }, { "S", 0, -1 }, { "W", -1, 0 } }) do
        local fs = canvas:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        fs:SetText(c[1])
        compass[#compass + 1] = { fs = fs, dx = c[2], dy = c[3] }
    end

    -- positions only, text and colors belong to AZT.SetSafeQuads, since this
    -- runs every frame in the rotating/centered view modes. mapRot rotates the
    -- room around its center. offX/offY shift the room (player-centered mode).
    local function layoutQuads(mapRot, offX, offY)
        mapRot = mapRot or view.mapRot or 0
        offX = offX or view.offX or 0
        offY = offY or view.offY or 0
        view.mapRot, view.offX, view.offY = mapRot, offX, offY
        local cosm, sinm = math.cos(mapRot), math.sin(mapRot)
        for _, tl in ipairs(artTiles) do
            tl.tex:SetRotation(mapRot)
            tl.tex:ClearAllPoints()
            tl.tex:SetPoint(
                "CENTER",
                canvas,
                "CENTER",
                offX + tl.dx * cosm - tl.dy * sinm,
                offY + tl.dx * sinm + tl.dy * cosm
            )
        end
        for _, c in ipairs(compass) do
            c.fs:ClearAllPoints()
            c.fs:SetPoint(
                "CENTER",
                canvas,
                "CENTER",
                (c.dx * cosm - c.dy * sinm) * edge,
                (c.dx * sinm + c.dy * cosm) * edge
            )
        end
        disc:ClearAllPoints()
        disc:SetPoint("CENTER", canvas, "CENTER", offX, offY)
        center:ClearAllPoints()
        center:SetPoint("CENTER", canvas, "CENTER", offX, offY)
        local rot = GRID_ROT + mapRot
        local cosr, sinr = math.cos(rot), math.sin(rot)
        ns:SetRotation(rot)
        ns:ClearAllPoints()
        ns:SetPoint("CENTER", canvas, "CENTER", offX, offY)
        ew:SetRotation(rot)
        ew:ClearAllPoints()
        ew:SetPoint("CENTER", canvas, "CENTER", offX, offY)
        for i, q in ipairs(QUADS) do
            -- wedge bbox center sits at (dx, dy) * r/2 from room center:
            -- rotating texture about its own bbox center + moving the bbox
            -- center along the same rotation = rotation about room center
            local ox, oy = q.dx * rp / 2, q.dy * rp / 2
            local w = wedges[i]
            w:ClearAllPoints()
            w:SetPoint("CENTER", canvas, "CENTER", offX + ox * cosr - oy * sinr, offY + ox * sinr + oy * cosr)
            w:SetRotation(rot)
            local lx, ly = q.dx * 0.62 * rp / 1.4142, q.dy * 0.62 * rp / 1.4142
            local fs = qlabels[i]
            fs:ClearAllPoints()
            fs:SetPoint("CENTER", canvas, "CENTER", offX + lx * cosr - ly * sinr, offY + lx * sinr + ly * cosr)
        end
    end
    view.layoutQuads = layoutQuads
    view.QUADS, view.wedges, view.qlabels = QUADS, wedges, qlabels
    layoutQuads(0, 0, 0)
    AZT.SetSafeQuads(AZT.Safe and AZT.Safe.GetSequence() or nil)

    -- player arrow (texture points north, SetRotation is CCW like facing)
    local arrow = canvas:CreateTexture(nil, "OVERLAY")
    arrow:SetSize(30, 30)
    arrow:SetTexture("Interface\\Minimap\\MinimapArrow")
    arrow:SetPoint("CENTER")
    view.arrow = arrow

    -- fallback marker when facing is unavailable (combat restrictions):
    -- position still shows, direction doesn't pretend to be known
    local blip = canvas:CreateTexture(nil, "OVERLAY")
    blip:SetSize(10, 10)
    blip:SetTexture("Interface\\CharacterFrame\\TempPortraitAlphaMask")
    blip:SetVertexColor(1, 0.9, 0.2, 1)
    blip:SetPoint("CENTER")
    blip:Hide()
    view.blip = blip

    local status = view:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    status:SetPoint("BOTTOM", 0, 8)
    view.status = status

    attachLock(view, "room", { helpBtn }, -26, -4)

    local elapsed = 0
    view:SetScript("OnUpdate", function(_, dt)
        elapsed = elapsed + dt
        if elapsed < 0.05 then
            return
        end
        elapsed = 0

        local ok, a, b = pcall(UnitPosition, "player")
        if not ok or not a or not b then
            arrow:Hide()
            blip:Hide()
            status:SetText("position unavailable")
            return
        end

        -- room-local yards: x = east(+)/west(-), y = north(+)/south(-)
        local okX, x, y = pcall(function()
            return ROOM.centerB - b, a - ROOM.centerA
        end)
        if not okX then
            arrow:Hide()
            blip:Hide()
            status:SetText("position secret")
            return
        end

        local dist = math.sqrt(x * x + y * y)
        local maxR = ROOM.radius + ROOM.pad
        local alpha = 1
        if dist > maxR then
            -- clamp to the view edge, dimmed, so it still shows the direction
            x, y = x * maxR / dist, y * maxR / dist
            alpha = 0.4
        end

        local okF, facing = pcall(GetPlayerFacing)

        -- view modes: static = north up; rotate = facing up; player = facing
        -- up AND player pinned to the canvas center, room moves around them
        local mode = AztarecHelperDB.viewMode or "static"
        local mapRot = 0
        if mode ~= "static" and okF and facing then
            local okN, neg = pcall(function()
                return -facing
            end)
            if okN and type(neg) == "number" then
                mapRot = neg
            end
        end
        local cosm, sinm = math.cos(mapRot), math.sin(mapRot)
        local sx, sy = x * cosm - y * sinm, x * sinm + y * cosm
        local offX, offY, mx, my = 0, 0, sx * ppy, sy * ppy
        if mode == "player" then
            offX, offY, mx, my = -sx * ppy, -sy * ppy, 0, 0
        end
        if
            math.abs(mapRot - (view.mapRot or 0)) > 0.01
            or math.abs(offX - (view.offX or 0)) > 0.5
            or math.abs(offY - (view.offY or 0)) > 0.5
        then
            view.layoutQuads(mapRot, offX, offY)
        end

        -- facing may go secret/nil in combat: fall back to the plain blip
        local marker
        local okR, rotVal = pcall(function()
            return facing + mapRot
        end)
        if okF and facing and okR and pcall(arrow.SetRotation, arrow, rotVal) then
            marker = arrow
            blip:Hide()
        else
            marker = blip
            arrow:Hide()
        end
        marker:SetAlpha(alpha)
        marker:ClearAllPoints()
        marker:SetPoint("CENTER", canvas, "CENTER", mx, my)
        marker:Show()

        local okS, s = pcall(
            string.format,
            "%.1f yd %s of center",
            dist,
            dist < 1 and "" or (y >= 0 and (x >= 0 and "NE" or "NW") or (x >= 0 and "SE" or "SW"))
        )
        status:SetText(okS and s or "")
    end)
end

-- highlight the captured safe-spot sequence (list of quadrant names).
-- Without activeIdx (capture phase): captured spots green + numbered.
-- With activeIdx (echo replay): current safe = green, next safe = yellow,
-- all other quadrants = red danger. Empty/nil list restores neutral.
-- marks[k] flags spots that were recorded shakily. They get a ? suffix.
function AZT.SetSafeQuads(list, activeIdx, marks)
    safeNow = list and activeIdx and list[activeIdx] or nil
    nextNow = list and activeIdx and list[activeIdx + 1] or nil
    stayText = safeNow
            and (nextNow and nextNow ~= safeNow and ("stay " .. safeNow .. ", next " .. nextNow) or ("stay " .. safeNow))
        or nil
    if AZT.ArrowSync then
        AZT.ArrowSync()
    end
    if not view then
        return
    end
    for i, q in ipairs(view.QUADS) do
        local orders = {}
        for k, sq in ipairs(list or {}) do
            if sq == q.name then
                orders[#orders + 1] = (marks and marks[k]) and (k .. "?") or tostring(k)
            end
        end
        local label = #orders > 0 and (table.concat(orders, ",") .. ":" .. q.name) or q.name
        local w, fs = view.wedges[i], view.qlabels[i]
        if safeNow then
            if q.name == safeNow then
                w:SetVertexColor(0.1, 0.9, 0.2, 0.5)
                fs:SetTextColor(0.4, 1, 0.5, 1)
            elseif q.name == nextNow then
                w:SetVertexColor(1, 0.85, 0.1, 0.45)
                fs:SetTextColor(1, 0.95, 0.4, 1)
            else
                w:SetVertexColor(0.9, 0.12, 0.08, 0.4)
                fs:SetTextColor(1, 0.4, 0.35, 1)
            end
            fs:SetText(label)
        elseif #orders > 0 then
            w:SetVertexColor(0.15, 0.9, 0.25, 0.35)
            fs:SetTextColor(0.35, 1, 0.45, 1)
            fs:SetText(label)
        else
            w:SetVertexColor(1, 1, 1, q.shade)
            fs:SetText(q.name)
            fs:SetTextColor(1, 1, 1, 0.65)
        end
    end
end

-- shared drag wiring for the small floating windows
local function makeMovable(frame, posKey, defPoint, defX, defY)
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

--#region Wave text
-- The countdown gets its own little window so it can sit where the player
-- actually looks during the fight, independent of the room view.

local waveFrame
local FLASH_UNDER = 1.5 -- countdown starts pulsing this close to a hit
local FLASH_HZ = 2.0
local COUNT_CAP = 9 -- a countdown longer than this is noise, not help

local function buildWave()
    waveFrame = CreateFrame("Frame", "AztarecHelperWaveText", UIParent)
    waveFrame:SetSize(230, 34)
    makeMovable(waveFrame, "wavePos", "TOP", 0, -180)

    local bg = waveFrame:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetColorTexture(0, 0, 0, 0.25)
    local text = waveFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    text:SetPoint("CENTER")
    waveFrame.text = text
    attachLock(waveFrame, "wave")
    waveFrame:Hide()

    local elapsed = 0
    waveFrame:SetScript("OnUpdate", function(_, dt)
        elapsed = elapsed + dt
        if elapsed < 0.05 then
            return
        end
        elapsed = 0
        local w = AZT.Wave
        if not w or not w.phase then
            return
        end
        local msg
        if w.phase == "record" then
            msg = ("recording wave %d"):format(w.idx)
        elseif w.total then
            msg = ("wave %d of %d"):format(w.idx, w.total)
        else
            msg = ("wave %d"):format(w.idx)
        end
        local remain
        if w.at then
            local okR, r = pcall(function()
                return w.at - GetTime()
            end)
            if okR and type(r) == "number" and r > 0 and r <= COUNT_CAP then
                remain = r
            end
        end
        if remain then
            msg = msg .. (" - %.1f"):format(remain)
        end
        local rC, gC, bC = 1, 1, 1
        if w.phase ~= "record" and AztarecHelperDB.moveWarn and safeNow then
            local quadNow = AZT.Safe and AZT.Safe.CurrentQuadrant()
            if quadNow == safeNow then
                rC, gC, bC = 0.4, 1, 0.5
            elseif quadNow then
                msg = "MOVE  " .. msg
                rC, gC, bC = 1, 0.25, 0.2
            end
        end
        local alpha = 1
        if remain and remain < FLASH_UNDER then
            alpha = 0.55 + 0.45 * math.abs(math.sin(GetTime() * FLASH_HZ * math.pi))
        end
        text:SetText(msg)
        text:SetTextColor(rC, gC, bC, alpha)
    end)
end

-- shows while there is wave state to render, hides the moment it clears
function AZT.WaveSync()
    local live = AZT.Wave and AZT.Wave.phase ~= nil
    local on = AztarecHelperDB.waveText and (live or AZT.placeMode)
    if not waveFrame then
        if not on then
            return
        end
        buildWave()
    end
    waveFrame:SetShown(on and true or false)
    if on and not live then
        -- placement sample in the widest state the current settings allow,
        -- so the chosen spot fits the real thing under pressure
        if AztarecHelperDB.moveWarn then
            waveFrame.text:SetText("MOVE  wave 2 of 5 - 1.8")
            waveFrame.text:SetTextColor(1, 0.25, 0.2, 1)
        else
            waveFrame.text:SetText("wave 2 of 5 - 1.8")
            waveFrame.text:SetTextColor(1, 1, 1, 1)
        end
    end
end

--#endregion

--#region Safe arrow
-- Points from where you stand to the called safe quadrant, quest-arrow
-- style. Red on the way in, green once you stand right (then it aims ahead
-- at the next call), grey around the delve out of combat so it can be
-- dragged into place. In combat it only exists while the memory game runs.

local arrowFrame
local QUAD_RAD = { N = 0, E = math.rad(90), S = math.rad(180), W = math.rad(270) }
local REACH = AZT.ROOM.radius * 0.6 -- aim point: the quarter's center of area

-- plain named functions so the per-tick pcalls allocate nothing
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
    makeMovable(arrowFrame, "arrowPos", "TOP", 0, -100)

    -- our own arrow art. Blizzard's guide arrow blp turned out to carry
    -- baked-in translucency no blend mode gets around, so this ships as a
    -- proper opaque texture instead
    local tex = arrowFrame:CreateTexture(nil, "ARTWORK")
    tex:SetSize(88, 88)
    tex:SetPoint("TOP", 0, -18)
    tex:SetTexture("Interface\\AddOns\\AztarecHelper\\arrow")
    tex:Hide()

    local label = arrowFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    label:SetPoint("BOTTOM")
    arrowFrame.label = label
    attachLock(arrowFrame, "arrow")
    arrowFrame:Hide()

    -- color multiplied onto the desaturated art per state. No entry means no
    -- tint, the art shows gold as drawn.
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
    -- big ones, an eased about-face reads as lag
    local function easeTo(rot)
        local delta = (rot - shownRot + math.pi) % (2 * math.pi) - math.pi
        if math.abs(delta) > TURN_SNAP then
            shownRot = rot
        else
            shownRot = shownRot + delta * TURN_SMOOTH
        end
        return shownRot
    end

    -- bearing and distance from the player to a quadrant's center of area:
    -- for a quarter slice that sits about six tenths of the way out along its
    -- middle line. Facing can go secret in combat, then rot comes back nil
    -- and the name and distance still help.
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
        if not safeNow then
            return -- parked, ArrowSync painted the waiting state already
        end
        local q, x, y = AZT.Safe.CurrentQuadrant()
        if not x then
            -- position reads drop out for a moment now and then, so the last
            -- verdict stays up briefly instead of flickering to nothing
            if GetTime() - lastReadAt > SAFE_HOLD then
                hidePointer()
                label:SetText(safeNow)
                label:SetTextColor(1, 1, 1)
            end
            return
        end
        lastReadAt = GetTime()

        if q == safeNow then
            -- standing right: green, and pointing ahead at the next quarter
            -- so the move can start the moment the wave resolves. No next
            -- (or next is this one): point down, you are the destination.
            label:SetTextColor(0.4, 1, 0.5)
            label:SetText(stayText)
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
    local live = safeNow ~= nil
    local recording = AZT.Wave and AZT.Wave.phase == "record"
    -- grey and grabbable around the delve out of combat. Once a fight is on,
    -- by the regen flag, the lockdown API or an armed encounter, it only
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
        -- the caption helps placement, mid-fight it is clutter
        arrowFrame.label:SetText(fighting and "" or "safe-spot arrow")
        arrowFrame.label:SetTextColor(1, 1, 1, 0.5)
    end
end

--#endregion

--#region Window controls

-- placement mode: show the floating windows anywhere, so they can be dragged
-- into place without pulling the boss first. Session state, never saved.
function AZT.SetPlaceMode(v)
    AZT.placeMode = v and true or false
    AZT.WaveSync()
    AZT.ArrowSync()
    AZT.chat(
        AZT.placeMode and "placement mode ON - drag the countdown and the arrow where you want them"
            or "placement mode off"
    )
end

function AZT.ToggleMapArt()
    AztarecHelperDB.mapArt = not AztarecHelperDB.mapArt
    local on = AztarecHelperDB.mapArt
    if view then
        for _, tl in ipairs(view.artTiles or {}) do
            tl.tex:SetShown(on)
        end
        local haveArt = view.artTiles and #view.artTiles > 0
        view.disc:SetVertexColor(0.25, 0.45, 0.70, (on and haveArt) and 0.15 or 0.40)
    end
    AZT.chat("map art backdrop: " .. (on and "ON" or "OFF"))
end

function AZT.CycleViewMode(silent)
    local cur = AztarecHelperDB.viewMode or "static"
    for i, m in ipairs(VIEW_MODES) do
        if m == cur then
            AztarecHelperDB.viewMode = VIEW_MODES[i % #VIEW_MODES + 1]
            break
        end
    end
    if not silent then
        AZT.chat("room view mode: " .. VIEW_MODE_LABEL[AztarecHelperDB.viewMode])
    end
end

-- the preference is remembered, so a hidden room view stays hidden across
-- zone changes until it is asked for again
function AZT.SetRoomShown(v)
    AztarecHelperDB.roomView = v and true or false
    if not v then
        if view and view:IsShown() then
            view:Hide()
        end
        AZT.chat("room view hidden - /azt room or the options panel brings it back")
        return
    end
    if not view then
        build()
    end
    view:Show()
    AZT.chat("room view shown - drag to move")
end

function AZT.ToggleRoomView()
    AZT.SetRoomShown(not (view and view:IsShown()))
end

-- for callers that need the view on screen without toggling it (replay)
function AZT.EnsureRoomView()
    if not view then
        build()
    end
    if not view:IsShown() then
        view:Show()
    end
end

function AZT.ViewModeLabel()
    return VIEW_MODE_LABEL[AztarecHelperDB.viewMode or "static"]
end

-- auto show/hide on zone change
local zf = CreateFrame("Frame")
zf:RegisterEvent("PLAYER_ENTERING_WORLD")
zf:RegisterEvent("ZONE_CHANGED_NEW_AREA")
-- regen events too, the arrow shows and hides on combat edges
zf:RegisterEvent("PLAYER_REGEN_DISABLED")
zf:RegisterEvent("PLAYER_REGEN_ENABLED")
zf:SetScript("OnEvent", function(_, event)
    -- own combat flag, kept from the regen edges, so the arrow logic never
    -- depends on how early the lockdown API flips
    if event == "PLAYER_REGEN_DISABLED" then
        AZT.inCombat = true
    elseif event == "PLAYER_REGEN_ENABLED" then
        AZT.inCombat = false
    elseif event == "PLAYER_ENTERING_WORLD" then
        AZT.inCombat = InCombatLockdown() and true or false
    end
    if AZT.ArrowSync then
        AZT.ArrowSync()
    end
    if AZT.InDelve() and AztarecHelperDB.roomView then
        if not view then
            build()
        end
        if not view:IsShown() then
            view:Show()
            AZT.chat("entered Venomfall Deeps - room view on (/azt room to hide)")
            if AZT.Recorder then
                -- scenario state streams in shortly AFTER the zone event, so
                -- probing it here yields nil on a fresh walk-in, hence the timer
                C_Timer.NewTimer(2, function()
                    local s = AZT.Recorder.ScenarioText()
                    if s and not s:find("=nil") then
                        AZT.chat(s)
                    end
                end)
            end
        end
    elseif view and view:IsShown() then
        view:Hide()
    end
end)

--#endregion
