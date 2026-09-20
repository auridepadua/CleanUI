-- CleanUI — minimalist UI for WoW Forever
--
-- Each UI element is an independently toggleable "element": bag bar, micro menu
-- and XP/status bar are hidden by reparenting their frames under a permanently
-- hidden holder (reversible — the original parent is remembered so they can be
-- restored). The quest tracker is a special case: it's a managed Edit Mode
-- frame that the layout system re-shows through a path that bypasses :Show(),
-- so it's kept down with a Show hook plus a throttled watchdog.
--
-- All frame lookups are guarded so renamed frames fail silently.

local hidden = CreateFrame("Frame")
hidden:Hide()

-- Reparent a frame under the hidden holder, remembering where it came from.
local function hideFrame(frame)
    if not frame then return end
    if not frame.cleanuiOrigParent then
        frame.cleanuiOrigParent = frame:GetParent() or UIParent
    end
    frame:Hide()
    frame:SetParent(hidden)
end

-- Restore a frame to its original parent and show it again.
local function showFrame(frame)
    if not frame then return end
    if frame.cleanuiOrigParent then
        frame:SetParent(frame.cleanuiOrigParent)
    end
    frame:Show()
end

-- Collect the existing global frames named in a list.
local function resolve(names, into)
    into = into or {}
    for _, name in ipairs(names) do
        if _G[name] then
            table.insert(into, _G[name])
        end
    end
    return into
end

-- Toggleable elements ------------------------------------------------------
-- collect() returns the live frames that make up the element. `secure` marks
-- elements with protected frames that can't be reparented during combat.
local elements = {
    bagbar = {
        name = "bag bar",
        hidden = true,
        secure = true,
        collect = function()
            local t = {}
            if BagsBar then table.insert(t, BagsBar) end
            return resolve({
                "MainMenuBarBackpackButton",
                "CharacterBag0Slot", "CharacterBag1Slot",
                "CharacterBag2Slot", "CharacterBag3Slot",
                "CharacterReagentBag0Slot",
            }, t)
        end,
    },
    microbar = {
        name = "micro menu",
        hidden = true,
        secure = true,
        collect = function()
            local t = {}
            local container = MicroMenuContainer or MicroMenu or MicroButtonAndBagsBar
            if container then table.insert(t, container) end
            return resolve({
                "CharacterMicroButton", "ProfessionMicroButton", "SpellbookMicroButton",
                "TalentMicroButton", "AchievementMicroButton", "QuestLogMicroButton",
                "GuildMicroButton", "SocialsMicroButton", "WorldMapMicroButton",
                "MainHelpMicroButton", "GameMenuMicroButton", "StoreMicroButton",
                "CollectionsMicroButton", "EJMicroButton", "LFDMicroButton",
                "PVPMicroButton", "HelpMicroButton",
            }, t)
        end,
    },
    expbar = {
        name = "XP bar",
        hidden = true,
        collect = function()
            return resolve({
                "StatusTrackingBarManager",
                "MainStatusTrackingBarContainer",
                "SecondaryStatusTrackingBarContainer",
                "MainMenuExpBar",
                "MainStatusBar",
            })
        end,
    },
}

-- Apply an element's hidden/shown state to all its frames.
local function setElement(el, hide)
    if el.secure and InCombatLockdown() then
        print("CleanUI: can't toggle " .. el.name .. " in combat — try again after")
        return
    end
    for _, frame in ipairs(el.collect()) do
        if hide then hideFrame(frame) else showFrame(frame) end
    end
    el.hidden = hide
end

-- Quest tracker ------------------------------------------------------------
-- ObjectiveTrackerFrame is managed by RightManagedFrameContainer (Edit Mode).
-- Hiding it once doesn't stick: the layout system re-shows it via a path that
-- bypasses :Show(). So we (a) hook Show for the instant, no-flicker case, and
-- (b) run a throttled watchdog that re-hides it whenever it slips back on.
local trackerHidden = true
local trackerHookSet = false

local function getTracker()
    return ObjectiveTrackerFrame or QuestWatchFrame
end

local function hideTracker()
    local t = getTracker()
    if not t then return end
    trackerHidden = true
    t:Hide()
    if not trackerHookSet then
        trackerHookSet = true
        hooksecurefunc(t, "Show", function(self)
            if trackerHidden then self:Hide() end
        end)
    end
end

local function showTracker()
    local t = getTracker()
    if not t then return end
    trackerHidden = false
    t:Show()
end

-- Minimalist XP bar --------------------------------------------------------
-- A slim horizontal bar styled after the minimap zone-text bar, sitting just
-- beneath it and matching its width. Shows XP as a fill (purple = current,
-- blue = rested ahead of it) with a gold percentage, echoing the zone bar's
-- look. Replaces the hidden Blizzard status bar.
local XP_PURPLE = { 0.62, 0.00, 0.60 } -- current XP, like the default bar
local XP_BLUE   = { 0.10, 0.45, 1.00 } -- rested bonus
local XP_GOLD   = { 1.00, 0.82, 0.00 } -- percentage text, like the zone text
local BAR_TEX = "Interface\\TargetingFrame\\UI-StatusBar"
local xpBar
local xpUserHidden = false

-- Layout settings, live-adjustable via /cleanui config. Stored in CleanUIDB so
-- they persist once Blizzard fixes SavedVariables on the beta; until then they
-- just reset to these defaults each session. width = nil means "measure the
-- top row on first build".
CleanUIDB = CleanUIDB or {}
local db = CleanUIDB
local XP_DEFAULTS = { width = 207, height = 9, xoff = 15, yoff = -5 }
for k, v in pairs(XP_DEFAULTS) do
    if db[k] == nil then db[k] = v end
end

-- The minimap zone-text bar we hang beneath (name varies by client build).
local function getZoneAnchor()
    if MinimapCluster then
        return MinimapCluster.ZoneTextButton
            or MinimapCluster.BorderTop
            or MinimapCluster
    end
    return MinimapZoneTextButton or MinimapBorderTop or Minimap
end

-- Size and position the bar from the current settings (called live by sliders).
local function ApplyXPLayout()
    if not xpBar then return end
    local w = db.width or (Minimap and Minimap:GetWidth()) or 200
    xpBar:ClearAllPoints()
    xpBar:SetSize(w, db.height)
    local anchor = getZoneAnchor() or Minimap or UIParent
    xpBar:SetPoint("TOP", anchor, "BOTTOM", db.xoff, db.yoff)
    if xpBar.sheen then xpBar.sheen:SetHeight(db.height * 0.55) end
    if xpBar.shadow then xpBar.shadow:SetHeight(db.height * 0.45) end
end

local function UpdateXPBar()
    if not xpBar then return end
    local cur, max = UnitXP("player"), UnitXPMax("player")
    if not max or max == 0 then
        xpBar:Hide() -- max level: nothing to show
        return
    end
    if not xpUserHidden then xpBar:Show() end

    local rest = GetXPExhaustion() or 0
    -- outer bar (blue) carries current + rested; inner fill (purple) is current
    xpBar:SetMinMaxValues(0, max)
    xpBar:SetValue(math.min(cur + rest, max))
    xpBar.fill:SetMinMaxValues(0, max)
    xpBar.fill:SetValue(cur)
    xpBar.pct:SetFormattedText("%.1f%%", cur / max * 100)
    xpBar._cur, xpBar._max, xpBar._rest = cur, max, rest
end

local function CreateXPBar()
    if xpBar then return xpBar end
    local anchor = getZoneAnchor()
    if not anchor then return end

    -- Measure the top row (tracking button → calendar) as the default width the
    -- first time we build; after that db.width holds whatever the slider set.
    if not db.width then
        local track = MiniMapTrackingButton
            or (MinimapCluster and (MinimapCluster.Tracking or MinimapCluster.TrackingFrame))
        local left = track and track.GetLeft and track:GetLeft()
        local right = GameTimeFrame and GameTimeFrame.GetRight and GameTimeFrame:GetRight()
        if left and right and right > left then
            db.width = right - left
        else
            db.width = (Minimap and Minimap:GetWidth()) or 200
        end
    end

    -- Base bar = rested (blue) layer; size/position comes from ApplyXPLayout.
    local bar = CreateFrame("StatusBar", "CleanUIMiniXP", anchor:GetParent() or UIParent)
    bar:SetStatusBarTexture(BAR_TEX)
    bar:SetStatusBarColor(XP_BLUE[1], XP_BLUE[2], XP_BLUE[3], 0.85)
    bar:SetFrameStrata("MEDIUM")

    local bg = bar:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetColorTexture(0, 0, 0, 0.6)

    -- Inner fill = current XP (purple), drawn over the blue rested layer.
    local fill = CreateFrame("StatusBar", nil, bar)
    fill:SetAllPoints()
    fill:SetStatusBarTexture(BAR_TEX)
    fill:SetStatusBarColor(XP_PURPLE[1], XP_PURPLE[2], XP_PURPLE[3])
    bar.fill = fill

    -- Glossy sheen to match the player-frame bars: a bright highlight across
    -- the top and a soft shadow along the bottom, drawn above the fills.
    local gloss = CreateFrame("Frame", nil, bar)
    gloss:SetAllPoints(bar)
    gloss:SetFrameLevel(fill:GetFrameLevel() + 1)
    bar.gloss = gloss

    local sheen = gloss:CreateTexture(nil, "ARTWORK")
    sheen:SetPoint("TOPLEFT")
    sheen:SetPoint("TOPRIGHT")
    sheen:SetHeight(db.height * 0.55)
    sheen:SetColorTexture(1, 1, 1, 1)
    bar.sheen = sheen

    local shadow = gloss:CreateTexture(nil, "ARTWORK")
    shadow:SetPoint("BOTTOMLEFT")
    shadow:SetPoint("BOTTOMRIGHT")
    shadow:SetHeight(db.height * 0.45)
    shadow:SetColorTexture(0, 0, 0, 1)
    bar.shadow = shadow

    -- Gradient API changed across builds; support both.
    if sheen.SetGradient and CreateColor then
        sheen:SetGradient("VERTICAL", CreateColor(1, 1, 1, 0.0), CreateColor(1, 1, 1, 0.30))
        shadow:SetGradient("VERTICAL", CreateColor(0, 0, 0, 0.28), CreateColor(0, 0, 0, 0.0))
    elseif sheen.SetGradientAlpha then
        sheen:SetGradientAlpha("VERTICAL", 1, 1, 1, 0.0, 1, 1, 1, 0.30)
        shadow:SetGradientAlpha("VERTICAL", 0, 0, 0, 0.28, 0, 0, 0, 0.0)
    end

    -- Beveled border to echo the zone bar's frame.
    local border = CreateFrame("Frame", nil, bar, "BackdropTemplate")
    border:SetPoint("TOPLEFT", -3, 3)
    border:SetPoint("BOTTOMRIGHT", 3, -3)
    if border.SetBackdrop then
        border:SetBackdrop({
            edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
            edgeSize = 10,
        })
        border:SetBackdropBorderColor(0.18, 0.18, 0.18, 1) -- dark, like the zone bar
    end

    -- Gold percentage, right-aligned like the zone bar's clock.
    local pct = gloss:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    pct:SetPoint("RIGHT", bar, "RIGHT", -5, 0)
    pct:SetTextColor(XP_GOLD[1], XP_GOLD[2], XP_GOLD[3])
    bar.pct = pct

    -- Hover for the exact numbers.
    bar:EnableMouse(true)
    bar:SetScript("OnEnter", function(self)
        if not self._max or self._max == 0 then return end
        GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
        GameTooltip:AddLine("Experience")
        GameTooltip:AddDoubleLine("XP", string.format("%d / %d", self._cur, self._max),
            1, 1, 1, 1, 1, 1)
        GameTooltip:AddDoubleLine("Remaining",
            string.format("%d  (%.1f%%)", self._max - self._cur,
                (self._max - self._cur) / self._max * 100),
            1, 1, 1, 0.9, 0.9, 0.9)
        if self._rest and self._rest > 0 then
            GameTooltip:AddDoubleLine("Rested",
                string.format("%d  (%.1f%%)", self._rest, self._rest / self._max * 100),
                1, 1, 1, XP_BLUE[1], 0.6, XP_BLUE[3])
        end
        GameTooltip:Show()
    end)
    bar:SetScript("OnLeave", function() GameTooltip:Hide() end)

    xpBar = bar
    ApplyXPLayout()
    UpdateXPBar()
    return bar
end

-- Config GUI ---------------------------------------------------------------
local configFrame

local function makeSectionLabel(parent, text, yoff)
    local fs = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    fs:SetPoint("TOPLEFT", 22, yoff)
    fs:SetText(text)
    fs:SetTextColor(1, 0.82, 0)
    return fs
end

local function makeCheck(parent, label, yoff, getter, setter)
    local cb = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
    cb:SetPoint("TOPLEFT", 26, yoff)
    cb:SetSize(24, 24)
    local fs = cb.Text or cb:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    fs:ClearAllPoints()
    fs:SetPoint("LEFT", cb, "RIGHT", 2, 0)
    fs:SetText(label)
    cb:SetChecked(getter())
    cb._get = getter
    cb:SetScript("OnClick", function(self)
        setter(self:GetChecked() and true or false)
        self:SetChecked(getter()) -- re-sync if a combat lockdown blocked it
    end)
    return cb
end

local function makeSlider(parent, label, minv, maxv, yoff, getter, setter)
    local s = CreateFrame("Slider", nil, parent, "OptionsSliderTemplate")
    s:SetWidth(230)
    s:SetPoint("TOP", 0, yoff)
    s:SetMinMaxValues(minv, maxv)
    s:SetValueStep(1)
    if s.SetObeyStepOnDrag then s:SetObeyStepOnDrag(true) end
    if s.Low then s.Low:SetText(tostring(minv)) end
    if s.High then s.High:SetText(tostring(maxv)) end

    local title = s.Text or s:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    if not s.Text then title:SetPoint("BOTTOM", s, "TOP", 0, 2) end
    s._title = title

    s:SetValue(getter())
    title:SetText(label .. ": " .. math.floor(getter() + 0.5))
    s:SetScript("OnValueChanged", function(self, val)
        val = math.floor(val + 0.5)
        setter(val)
        self._title:SetText(label .. ": " .. val)
        ApplyXPLayout()
    end)
    return s
end

-- Getters/setters for each element, shared by the checkboxes.
local function setMiniXP(show)
    CreateXPBar()
    xpUserHidden = not show
    if not xpBar then return end
    if show then xpBar:Show(); UpdateXPBar() else xpBar:Hide() end
end

local function ToggleConfig()
    CreateXPBar()
    if not configFrame then
        local cf = CreateFrame("Frame", "CleanUIConfig", UIParent,
            BackdropTemplateMixin and "BackdropTemplate" or nil)
        cf:SetSize(300, 500)
        cf:SetPoint("CENTER")
        cf:SetFrameStrata("DIALOG")
        cf:EnableMouse(true)
        cf:SetMovable(true)
        cf:RegisterForDrag("LeftButton")
        cf:SetScript("OnDragStart", cf.StartMoving)
        cf:SetScript("OnDragStop", cf.StopMovingSizing)
        if cf.SetBackdrop then
            cf:SetBackdrop({
                bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
                edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
                edgeSize = 16,
                insets = { left = 4, right = 4, top = 4, bottom = 4 },
            })
        end

        local title = cf:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
        title:SetPoint("TOP", 0, -14)
        title:SetText("CleanUI")

        local close = CreateFrame("Button", nil, cf, "UIPanelCloseButton")
        close:SetPoint("TOPRIGHT", -4, -4)

        -- Element toggles ------------------------------------------------
        makeSectionLabel(cf, "Hide elements", -46)
        cf.checks = {}
        local function addCheck(label, yoff, getter, setter)
            table.insert(cf.checks, makeCheck(cf, label, yoff, getter, setter))
        end
        addCheck("Bag bar", -66,
            function() return elements.bagbar.hidden end,
            function(v) setElement(elements.bagbar, v) end)
        addCheck("Micro menu", -92,
            function() return elements.microbar.hidden end,
            function(v) setElement(elements.microbar, v) end)
        addCheck("Quest tracker", -118,
            function() return trackerHidden end,
            function(v) if v then hideTracker() else showTracker() end end)
        addCheck("Blizzard XP bar", -144,
            function() return elements.expbar.hidden end,
            function(v) setElement(elements.expbar, v) end)

        makeSectionLabel(cf, "XP bar", -178)
        addCheck("Show mini XP bar", -198,
            function() return not xpUserHidden end,
            function(v) setMiniXP(v) end)

        -- XP bar sizing --------------------------------------------------
        cf.sliders = {
            makeSlider(cf, "Width", 80, 500, -250,
                function() return db.width end, function(v) db.width = v end),
            makeSlider(cf, "Height", 4, 32, -298,
                function() return db.height end, function(v) db.height = v end),
            makeSlider(cf, "Horizontal offset", -150, 150, -346,
                function() return db.xoff end, function(v) db.xoff = v end),
            makeSlider(cf, "Vertical offset", -40, 20, -394,
                function() return db.yoff end, function(v) db.yoff = v end),
        }

        local reset = CreateFrame("Button", nil, cf, "UIPanelButtonTemplate")
        reset:SetSize(140, 22)
        reset:SetPoint("BOTTOM", 0, 16)
        reset:SetText("Reset XP bar size")
        reset:SetScript("OnClick", function()
            db.width, db.height = XP_DEFAULTS.width, XP_DEFAULTS.height
            db.xoff, db.yoff = XP_DEFAULTS.xoff, XP_DEFAULTS.yoff
            cf.sliders[1]:SetValue(db.width)
            cf.sliders[2]:SetValue(db.height)
            cf.sliders[3]:SetValue(db.xoff)
            cf.sliders[4]:SetValue(db.yoff)
            ApplyXPLayout()
        end)

        configFrame = cf
    end

    -- Re-sync checkbox states to the live values whenever the panel opens.
    if not configFrame:IsShown() then
        for _, cb in ipairs(configFrame.checks) do cb:SetChecked(cb._get()) end
    end
    configFrame:SetShown(not configFrame:IsShown())
end

-- Keep the bar in sync with XP changes. Some events may not exist on Forever,
-- so register each defensively.
local xpEvents = CreateFrame("Frame")
for _, ev in ipairs({
    "PLAYER_XP_UPDATE", "PLAYER_LEVEL_UP", "UPDATE_EXHAUSTION",
    "PLAYER_ENTERING_WORLD", "DISABLE_XP_GAIN", "ENABLE_XP_GAIN",
}) do
    pcall(xpEvents.RegisterEvent, xpEvents, ev)
end
xpEvents:SetScript("OnEvent", function() UpdateXPBar() end)

local function toggleXPBar()
    CreateXPBar()
    if not xpBar then
        print("CleanUI: minimap not ready yet")
        return
    end
    xpUserHidden = not xpUserHidden
    if xpUserHidden then
        xpBar:Hide()
        print("CleanUI: mini XP bar hidden")
    else
        xpBar:Show()
        UpdateXPBar()
        print("CleanUI: mini XP bar shown")
    end
end

-- Re-apply every element's current state (called on login / zone).
local function applyCleanUI()
    CreateXPBar()
    UpdateXPBar()
    for _, el in pairs(elements) do
        if el.hidden then setElement(el, true) end
    end
    if trackerHidden then hideTracker() end
end

local f = CreateFrame("Frame")
f:RegisterEvent("PLAYER_ENTERING_WORLD")
f:SetScript("OnEvent", applyCleanUI)

-- Watchdog: the managed layout system re-shows the tracker without calling
-- :Show(), so poll ~10x/sec and force it back down while it should be hidden.
-- No-op once it's actually hidden (IsShown() is false), so the cost is trivial.
local sinceCheck = 0
f:SetScript("OnUpdate", function(self, dt)
    if not trackerHidden then return end
    sinceCheck = sinceCheck + dt
    if sinceCheck < 0.1 then return end
    sinceCheck = 0
    -- Tracker watchdog: re-hide it whenever the layout system sneaks it back.
    local t = getTracker()
    if t and t:IsShown() then t:Hide() end
end)

-- Slash commands ----------------------------------------------------------
-- Aliases so "/cleanui bag", "/cleanui bags" etc. all work.
local aliases = {
    quest = "quest",
    expbar = "expbar", exp = "expbar",
    microbar = "microbar", micro = "microbar",
    bagbar = "bagbar", bag = "bagbar", bags = "bagbar",
    minixp = "minixp", mini = "minixp", xp = "minixp",
    config = "config", gui = "config", options = "config", settings = "config",
}

local function toggleTracker()
    if trackerHidden then
        showTracker()
        print("CleanUI: quest tracker shown")
    else
        hideTracker()
        print("CleanUI: quest tracker hidden")
    end
end

local function printHelp()
    print("CleanUI — toggle UI elements:")
    print("  /cleanui quest     — quest tracker")
    print("  /cleanui expbar    — Blizzard XP / status bar")
    print("  /cleanui microbar  — micro menu")
    print("  /cleanui bagbar    — bag bar")
    print("  /cleanui minixp    — minimalist XP bar under the minimap")
    print("  /cleanui config    — open the XP bar settings panel")
    print("  /cleanui find      — print the frame under your mouse")
end

SLASH_CLEANUI1 = "/cleanui"
SlashCmdList["CLEANUI"] = function(msg)
    msg = (msg or ""):lower():gsub("%s+", "")
    local key = aliases[msg]

    if key == "quest" then
        toggleTracker()

    elseif key == "minixp" then
        toggleXPBar()

    elseif key == "config" then
        ToggleConfig()

    elseif key then
        local el = elements[key]
        setElement(el, not el.hidden)
        print("CleanUI: " .. el.name .. (el.hidden and " hidden" or " shown"))

    elseif msg == "find" then
        -- Print the name + parent of whatever is under the mouse, to discover
        -- exact Forever frame names. Hover the element, then run the command.
        local foci
        if GetMouseFoci then
            foci = GetMouseFoci()
        elseif GetMouseFocus then
            foci = { GetMouseFocus() }
        end
        if not foci or #foci == 0 then
            print("CleanUI: nothing under the mouse")
            return
        end
        for _, frame in ipairs(foci) do
            local name = frame.GetName and frame:GetName() or "<anonymous>"
            local parent = frame.GetParent and frame:GetParent()
            local pname = parent and parent.GetName and parent:GetName() or "?"
            print(("CleanUI: %s  (parent: %s)"):format(name or "<anonymous>", pname or "?"))
        end

    else
        printHelp()
    end
end
