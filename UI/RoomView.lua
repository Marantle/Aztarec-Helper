-- Azta'rec Helper, copyright 2026 Rothirr, all rights reserved.
-- Read it if you want. Copying any of it into another addon is theft, and
-- running it through an AI tool first does not change that. The timings and
-- coordinates were measured by hand. Nothing here is licensed to anyone.

local _, AZT = ...

-- The top-down room view: room circle, map art backdrop, quadrant wedges
-- and the player as a live marker. Follows the delve automatically for as
-- long as the player wants it around. /azt room and the options panel
-- decide that.

local SIZE = 300 -- canvas px, covers 2 * (radius + pad) yards
local GRID_ROT = math.rad(45) -- the quarter grid sits turned so boundaries hit the diagonals

local VIEW_MODES = { "static", "rotate", "player" }
local VIEW_MODE_LABEL = { static = "North up", rotate = "Facing up", player = "Centered" }

local view

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
        GameTooltip:AddDoubleLine("/azt spin", "north up, facing up or centered on you", 1, 0.82, 0, 1, 1, 1)
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

    -- positions only. Text and colors belong to AZT.SetSafeQuads since this
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
    -- position still shows but the direction doesn't pretend to be known
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

    AZT.AttachLock(view, "room", { helpBtn }, -26, -4)

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
    local safeNow = list and activeIdx and list[activeIdx] or nil
    local nextNow = list and activeIdx and list[activeIdx + 1] or nil
    AZT.safeNow, AZT.nextNow = safeNow, nextNow
    AZT.stayText = safeNow
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

--#region Controls

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
-- regen events too since the arrow shows and hides on combat edges
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
