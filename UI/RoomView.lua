-- Azta'rec Helper, copyright 2026 Rothirr, all rights reserved.
-- Read it if you want. Copying any of it into another addon is theft, and
-- running it through an AI tool first does not change that. The timings and
-- coordinates were measured by hand. Nothing here is licensed to anyone.

local _, AZT = ...

-- The top-down room view: room circle, map art backdrop and quadrant
-- wedges, north up. Follows the delve automatically for as long as the
-- player wants it around. /azt room and the options panel decide that.

local SIZE = 300 -- canvas px, covers 2 * (radius + pad) yards
local GRID_ROT = math.rad(45) -- the quarter grid sits turned so boundaries hit the diagonals

local view

-- players who drop world marker flags in the room think in those, not in
-- compass letters, so each quarter label can show a marker icon instead
local MARKS = { "Star", "Circle", "Diamond", "Triangle", "Moon", "Square", "Cross", "Skull" }

local function labelMenu(owner, qname)
    MenuUtil.CreateContextMenu(owner, function(_, root)
        root:CreateTitle(qname .. " quarter shows")
        root:CreateButton("Letter " .. qname, function()
            AztarecHelperDB.quadIcons[qname] = nil
            AZT.SetSafeQuads(AZT.Safe and AZT.Safe.GetSequence() or nil)
        end)
        for i, mark in ipairs(MARKS) do
            root:CreateButton(("|T" .. AZT.MARK_TEX .. ":16|t %s"):format(i, mark), function()
                AztarecHelperDB.quadIcons[qname] = i
                AZT.SetSafeQuads(AZT.Safe and AZT.Safe.GetSequence() or nil)
            end)
        end
    end)
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
        view:SetPoint("CENTER", UIParent, "CENTER", (SIZE + 24) * 1.5, 0)
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
    title:SetText("Azta'rec Helper")

    local optBtn = CreateFrame("Button", nil, view, "UIPanelButtonTemplate")
    optBtn:SetSize(74, 18)
    optBtn:SetPoint("TOPLEFT", 6, -4)
    optBtn:SetText("Options")
    optBtn:SetScript("OnClick", function()
        AZT.OpenOptions()
    end)

    -- the old ? in the corner held a tooltip nobody hovered mid-fight, so
    -- the strip the status line used to occupy carries a real button now
    local instrBtn = CreateFrame("Button", nil, view, "UIPanelButtonTemplate")
    instrBtn:SetSize(104, 18)
    instrBtn:SetPoint("BOTTOM", 0, 3)
    instrBtn:SetText("Instructions")
    instrBtn:SetScript("OnClick", function()
        AZT.ShowInstructions()
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

    -- map art backdrop: Blizzard's own tiles for uiMap 2634, drawn at board
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
    local labelBtns = {}
    local labelHints = {}
    local menuBtns = {}
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
        -- little dropdown arrow that advertises the icon menu while nothing
        -- is going on. QuadClickSync shows and hides it
        local hint = canvas:CreateTexture(nil, "OVERLAY")
        hint:SetSize(12, 12)
        hint:SetTexture("Interface\\ChatFrame\\ChatFrameExpandArrow")
        hint:SetRotation(-math.pi / 2)
        hint:SetVertexColor(1, 0.82, 0, 0.6)
        hint:SetPoint("LEFT", fs, "RIGHT", 0, -1)
        hint:Hide()
        labelHints[i] = hint
        -- the click target rides on the label
        local btn = CreateFrame("Button", nil, canvas)
        btn:SetAllPoints(fs)
        btn:SetScript("OnClick", function()
            labelMenu(btn, q.name)
        end)
        btn:SetScript("OnEnter", function(b)
            hint:SetVertexColor(1, 0.82, 0, 1)
            GameTooltip:SetOwner(b, "ANCHOR_RIGHT")
            GameTooltip:SetText("Click to select a different marker", 1, 1, 1, 1, true)
            GameTooltip:Show()
        end)
        btn:SetScript("OnLeave", function()
            hint:SetVertexColor(1, 0.82, 0, 0.6)
            GameTooltip:Hide()
        end)
        labelBtns[#labelBtns + 1] = btn
        menuBtns[i] = btn
    end

    -- each quarter wears the key that records it, so the board teaches the
    -- keys instead of the player having to remember which is which
    local BIND_CMD = {
        N = "AZTARECHELPER_MARK_NORTH",
        E = "AZTARECHELPER_MARK_EAST",
        S = "AZTARECHELPER_MARK_SOUTH",
        W = "AZTARECHELPER_MARK_WEST",
    }
    local keyTags = {}
    for i in ipairs(QUADS) do
        local tag = canvas:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        tag:SetPoint("TOP", qlabels[i], "BOTTOM", 0, -1)
        tag:SetTextColor(1, 0.82, 0, 0.75)
        keyTags[i] = tag
    end

    -- center marker (boss mechanic spot)
    local center = canvas:CreateTexture(nil, "ARTWORK", nil, 2)
    center:SetSize(6, 6)
    center:SetPoint("CENTER")
    center:SetColorTexture(1, 0.35, 0.35, 0.9)

    -- an empty binding is silent until the pull, so it says so here, in the
    -- gap between the room and the south compass letter
    local noKeys = canvas:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    noKeys:SetText("keybinds not set")
    noKeys:SetTextColor(1, 0.82, 0, 0.9)
    noKeys:Hide()

    -- compass letters on the view edge, the first thing to go when the
    -- window is cut down to the room
    local compass = {}
    local edge = SIZE / 2 - 8
    for _, c in ipairs({ { "N", 0, 1 }, { "E", 1, 0 }, { "S", 0, -1 }, { "W", -1, 0 } }) do
        local fs = canvas:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        fs:SetText(c[1])
        fs:SetPoint("CENTER", canvas, "CENTER", c[2] * edge, c[3] * edge)
        compass[#compass + 1] = fs
    end

    -- Slim cuts the canvas down to the room itself, so the border lands on
    -- the wall rather than a screen's worth of empty floor. Everything that
    -- lived out in that space goes with it, and the way into the settings
    -- shrinks rather than leaves.
    local function applyChrome()
        local slim = AztarecHelperDB.roomSlim
        local side = slim and math.floor(2 * rp + 4) or SIZE
        title:SetShown(not slim)
        instrBtn:SetShown(not slim)
        optBtn:SetSize(slim and 40 or 74, 18)
        optBtn:SetText(slim and "Opts" or "Options")
        for _, fs in ipairs(compass) do
            fs:SetShown(not slim)
        end
        canvas:SetSize(side, side)
        canvas:ClearAllPoints()
        canvas:SetPoint(slim and "CENTER" or "BOTTOM", 0, slim and 0 or 22)
        view:SetSize(side + (slim and 8 or 24), side + (slim and 8 or 46))
        -- below the wall normally, just inside it when there is no outside
        noKeys:ClearAllPoints()
        noKeys:SetPoint("CENTER", canvas, "CENTER", 0, slim and -(rp - 16) or -(rp + 18))
    end
    view.applyChrome = applyChrome
    applyChrome()

    -- fixed north-up layout. The grid draws turned 45 degrees so the wedges
    -- center on their cardinal names and the boundaries land on the
    -- diagonals. Text and colors belong to AZT.SetSafeQuads.
    local cosr, sinr = math.cos(GRID_ROT), math.sin(GRID_ROT)
    ns:SetRotation(GRID_ROT)
    ew:SetRotation(GRID_ROT)
    for _, tl in ipairs(artTiles) do
        tl.tex:SetPoint("CENTER", canvas, "CENTER", tl.dx, tl.dy)
    end
    for i, q in ipairs(QUADS) do
        -- wedge bbox center sits at (dx, dy) * r/2 from room center:
        -- rotating texture about its own bbox center + moving the bbox
        -- center along the same rotation = rotation about room center
        local ox, oy = q.dx * rp / 2, q.dy * rp / 2
        wedges[i]:SetPoint("CENTER", canvas, "CENTER", ox * cosr - oy * sinr, ox * sinr + oy * cosr)
        wedges[i]:SetRotation(GRID_ROT)
        local lx, ly = q.dx * 0.62 * rp / 1.4142, q.dy * 0.62 * rp / 1.4142
        qlabels[i]:SetPoint("CENTER", canvas, "CENTER", lx * cosr - ly * sinr, lx * sinr + ly * cosr)
    end
    view.QUADS, view.wedges, view.qlabels = QUADS, wedges, qlabels
    AZT.SetSafeQuads(AZT.Safe and AZT.Safe.GetSequence() or nil)

    -- clicking a quarter during the memory game records it, same as its
    -- quarter key. The targets only exist while a recording window is open,
    -- so outside the game they steal no clicks from dragging or the icon
    -- menus, and they stay deliberately outside the padlock's reach since
    -- the lock is there to stop accidental drags, not mid-fight input
    local quadHits = {}
    local flashes = {}
    for i, q in ipairs(QUADS) do
        -- own layer for the hover glow, so the route repaint and the mouse
        -- never fight over one texture's color
        local glow = canvas:CreateTexture(nil, "ARTWORK", nil, 4)
        glow:SetTexture("Interface\\CharacterFrame\\TempPortraitAlphaMask")
        glow:SetTexCoord(unpack(q.tc))
        glow:SetAllPoints(wedges[i])
        glow:SetRotation(GRID_ROT)
        glow:SetBlendMode("ADD")
        glow:SetVertexColor(1, 1, 1, 0.16)
        glow:Hide()

        local hit = CreateFrame("Button", nil, canvas)
        hit:SetAllPoints(wedges[i])
        -- above the label buttons, so a click near a letter still records
        hit:SetFrameLevel(canvas:GetFrameLevel() + 5)
        hit:SetScript("OnClick", function()
            AZT.Safe.CaptureQuadrant(q.name)
        end)
        hit:SetScript("OnEnter", function()
            glow:Show()
        end)
        hit:SetScript("OnLeave", function()
            glow:Hide()
        end)
        hit:SetScript("OnHide", function()
            glow:Hide()
        end)
        hit:Hide()
        quadHits[i] = hit

        -- press feedback: the answered quarter blinks once, so a key hit in
        -- the scramble is never in doubt
        local flash = canvas:CreateTexture(nil, "ARTWORK", nil, 5)
        flash:SetTexture("Interface\\CharacterFrame\\TempPortraitAlphaMask")
        flash:SetTexCoord(unpack(q.tc))
        flash:SetAllPoints(wedges[i])
        flash:SetRotation(GRID_ROT)
        flash:SetBlendMode("ADD")
        flash:SetVertexColor(1, 1, 1, 0.45)
        flash:Hide()
        local anim = flash:CreateAnimationGroup()
        local fade = anim:CreateAnimation("Alpha")
        fade:SetFromAlpha(1)
        fade:SetToAlpha(0)
        fade:SetDuration(0.35)
        anim:SetScript("OnFinished", function()
            flash:Hide()
        end)
        flashes[q.name] = { tex = flash, anim = anim }
    end

    function AZT.FlashQuad(name)
        local f = flashes[name]
        if not f or not view:IsShown() then
            return
        end
        f.anim:Stop()
        f.tex:Show()
        f.anim:Play()
    end

    function AZT.QuadClickSync()
        local w = AZT.Wave
        local recording = w and w.phase == "record"
        -- the quarters stay clickable through the echoes while any wave is
        -- still blank, since backfilling one is the only thing a click can
        -- do by then
        local canAnswer = recording
        if not canAnswer and w and w.phase == "echo" then
            for _, s in ipairs(AZT.safeList or {}) do
                if s == "?" then
                    canAnswer = true
                    break
                end
            end
        end
        for _, hit in ipairs(quadHits) do
            hit:SetShown(canAnswer and true or false)
        end
        -- the icon menus belong to the quiet moments. Mid-fight they would
        -- sit on top of the quarters and swallow clicks meant for recording,
        -- so they go away with their arrows
        local calm = not recording
            and not AZT.safeNow
            and not (w and w.phase)
            and not (AZT.inCombat or InCombatLockdown())
        for i, hint in ipairs(labelHints) do
            hint:SetShown(calm and true or false)
            menuBtns[i]:SetShown(calm and true or false)
        end
        -- the key tags help while learning and while recording, during the
        -- echoes the board is telling you where to go instead
        local echoing = w and (w.phase == "echo" or w.phase == "replay")
        local unbound = false
        for i, q in ipairs(QUADS) do
            local key = GetBindingKey(BIND_CMD[q.name])
            unbound = unbound or not key
            keyTags[i]:SetText(key and GetBindingText(key) or "")
            keyTags[i]:SetShown((key and not echoing) and true or false)
        end
        noKeys:SetShown((unbound and not echoing) and true or false)
    end
    AZT.QuadClickSync()

    AZT.AttachLock(view, "room", labelBtns, -6, -4)
end

-- highlight the recorded route (list of quarter names).
-- Without activeIdx (capture phase): captured spots green + numbered.
-- With activeIdx (echo replay): current safe = green, next safe = yellow,
-- all other quadrants = red danger. Empty/nil list restores neutral.
function AZT.SetSafeQuads(list, activeIdx)
    local safeNow = list and activeIdx and list[activeIdx] or nil
    local nextNow = list and activeIdx and list[activeIdx + 1] or nil
    AZT.safeNow, AZT.nextNow, AZT.safeList = safeNow, nextNow, list
    AZT.stayText = safeNow
            and (nextNow and nextNow ~= safeNow and ("stay " .. AZT.QuadName(safeNow, 18) .. ", next " .. AZT.QuadName(
                nextNow,
                18
            )) or ("stay " .. AZT.QuadName(safeNow, 18)))
        or nil
    if AZT.ArrowSync then
        AZT.ArrowSync()
    end
    if AZT.QuadClickSync then
        AZT.QuadClickSync()
    end
    if not view then
        return
    end
    for i, q in ipairs(view.QUADS) do
        local orders = {}
        for k, sq in ipairs(list or {}) do
            if sq == q.name then
                orders[#orders + 1] = tostring(k)
            end
        end
        local disp = AZT.QuadName(q.name, 42)
        local label = #orders > 0 and (table.concat(orders, ",") .. ":" .. disp) or disp
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
            fs:SetText(disp)
            -- the letters sit back at 0.65 but a chosen marker icon draws
            -- fully opaque, it is the player's own landmark
            local hasIcon = AztarecHelperDB.quadIcons and AztarecHelperDB.quadIcons[q.name]
            fs:SetTextColor(1, 1, 1, hasIcon and 1 or 0.65)
        end
    end
end

--#region Controls

function AZT.SetRoomSlim(v)
    AztarecHelperDB.roomSlim = v and true or false
    if view then
        view.applyChrome()
    end
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
    if AZT.WaveSync then
        AZT.WaveSync()
    end
    if AZT.QuadClickSync then
        AZT.QuadClickSync()
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
