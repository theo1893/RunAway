if RunAway.disabled then
    return
end

local utils = RunAway.utils
local filter = RunAway.filter

-- ============================================================================
-- Performance: Cache global functions locally
-- ============================================================================
local pairs = pairs
local ipairs = ipairs
local type = type
local abs = math.abs
local max = math.max
local format = string.format
local tinsert = table.insert
local tsort = table.sort

-- Cache WoW API functions used in hot paths
local UnitExists = UnitExists
local UnitHealth = UnitHealth
local UnitHealthMax = UnitHealthMax
local UnitName = UnitName
local UnitIsUnit = UnitIsUnit
local UnitAffectingCombat = UnitAffectingCombat
local UnitIsDead = UnitIsDead
local GetTime = GetTime
local GetRaidTargetIndex = GetRaidTargetIndex
local SetRaidTargetIconTexture = SetRaidTargetIconTexture

local ui = CreateFrame("Frame", nil, UIParent)
local templates = RunAway.templates

-- Single shared root frame (created once, reused for all bosses)
ui.rootFrame = nil
ui.currentBossName = nil  -- Track current boss to detect changes
ui.timers = {}
ui.lastSortUpdate = 0  -- Throttle sorting/layout updates
ui.sortUpdateInterval = 0.2  -- Update sorting every 0.2 seconds

-- Get current boss name from detected bosses
ui.GetCurrentBoss = function()
    if not RunAway.core or not RunAway.core.currentBosses then
        return nil
    end

    for guid, bossNameOrActive in pairs(RunAway.core.currentBosses) do
        -- bossNameOrActive is either the boss name (string) or true (legacy/fallback)
        if bossNameOrActive then
            local bossName = nil

            -- If stored value is a string, use it directly
            if type(bossNameOrActive) == "string" then
                bossName = bossNameOrActive
            -- Otherwise try to query the unit (fallback)
            elseif UnitExists(guid) then
                bossName = UnitName(guid)
            end

            if bossName and RunAway_db.bossLayouts[bossName] then
                return bossName
            end
        end
    end

    return nil
end

-- Clear all columns from the root frame
ui.ClearColumns = function()
    if not ui.rootFrame or not ui.rootFrame.columns then
        return
    end

    for colIndex, column in pairs(ui.rootFrame.columns) do
        -- Clear all bars in this column
        if column.bars then
            for guid, bar in pairs(column.bars) do
                bar:Hide()
                column.bars[guid] = nil
            end
        end
        column:Hide()
        ui.rootFrame.columns[colIndex] = nil
    end

    ui.rootFrame.columns = {}
end

-- Create the single shared root frame
ui.CreateRoot = function()
    local frame = CreateFrame("Frame", "RunAwayFrame", UIParent)

    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetMovable(true)

    frame:SetScript("OnDragStart", function()
        this.lock = true
        this:StartMoving()
    end)

    frame:SetScript("OnDragStop", function()
        this:StopMovingOrSizing()
        this.lock = false
        -- Save position to RunAway_db (single position for all bosses)
        local point, _, _, x, y = this:GetPoint()
        RunAway_db.framePosition = {
            anchor = point,
            x = x,
            y = y
        }
    end)

    frame:SetBackdrop(templates.background)
    frame:SetBackdropColor(0.1, 0.1, 0.1, 0.9)

    -- Create border
    local border = CreateFrame("Frame", nil, frame)
    border:SetBackdrop(templates.border)
    border:SetBackdropBorderColor(0.4, 0.4, 0.4, 1)
    border:SetPoint("TOPLEFT", frame, "TOPLEFT", -2, 2)
    border:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 2, -2)
    frame.border = border

    -- Create title text (will be updated dynamically)
    frame.caption = frame:CreateFontString(nil, "HIGH", "GameFontWhite")
    frame.caption:SetFont(STANDARD_TEXT_FONT, 10, "THINOUTLINE")
    frame.caption:SetPoint("TOP", frame, "TOP", 0, -4)
    frame.caption:SetTextColor(1, 1, 0, 1)
    frame.caption:SetText("RunAway")

    frame.columns = {}

    return frame
end

-- Create a column frame with unified style
ui.CreateColumn = function(parent, columnConfig, columnIndex)
    local column = CreateFrame("Frame", nil, parent)
    column.config = columnConfig
    column.index = columnIndex
    column.bars = {}

    -- Unified background style
    column:SetBackdrop(templates.background)

    -- Apply column-specific colors if defined, otherwise use defaults
    if columnConfig.colors and columnConfig.colors.bgColor then
        column:SetBackdropColor(unpack(columnConfig.colors.bgColor))
    else
        column:SetBackdropColor(0.15, 0.15, 0.15, 0.9)
    end

    -- Create column border with unified style
    local border = CreateFrame("Frame", nil, column)
    border:SetBackdrop(templates.border)
    border:SetPoint("TOPLEFT", column, "TOPLEFT", -2, 2)
    border:SetPoint("BOTTOMRIGHT", column, "BOTTOMRIGHT", 2, -2)

    if columnConfig.colors and columnConfig.colors.borderColor then
        border:SetBackdropBorderColor(unpack(columnConfig.colors.borderColor))
    else
        border:SetBackdropBorderColor(0.5, 0.5, 0.5, 1)
    end

    column.border = border

    -- Create column title with unified style
    column.title = column:CreateFontString(nil, "HIGH", "GameFontWhite")
    column.title:SetFont(STANDARD_TEXT_FONT, 9, "THINOUTLINE")
    column.title:SetPoint("TOP", column, "TOP", 0, -2)

    if columnConfig.colors and columnConfig.colors.titleColor then
        column.title:SetTextColor(unpack(columnConfig.colors.titleColor))
    else
        column.title:SetTextColor(1, 1, 1, 1)
    end
    column.title:SetText(columnConfig.title or "Column " .. columnIndex)

    return column
end

-- Create a unit bar with unified style
ui.CreateBar = function(parent, guid, unit_data, config)
    local frame = CreateFrame("Button", nil, parent)
    frame.guid = guid
    frame.unit_data = unit_data or {}

    -- Register events
    frame:RegisterEvent("UNIT_COMBAT")
    frame:SetScript("OnEvent", ui.BarEvent)
    frame:SetScript("OnClick", ui.BarClick)
    frame:SetScript("OnEnter", ui.BarEnter)
    frame:SetScript("OnLeave", ui.BarLeave)
    frame:SetScript("OnUpdate", ui.BarUpdate)

    frame:SetWidth(config.width)
    frame:SetHeight(config.height)

    -- Create health bar
    local bar = CreateFrame("StatusBar", nil, frame)
    bar:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
    bar:SetStatusBarColor(1, 0.8, 0.2, 1)
    bar:SetMinMaxValues(0, 100)
    bar:SetValue(20)
    bar:SetAllPoints()
    frame.bar = bar

    -- Create unit name text
    local text = bar:CreateFontString(nil, "HIGH", "GameFontWhite")
    text:SetPoint("TOPLEFT", bar, "TOPLEFT", 2, -2)
    text:SetPoint("BOTTOMRIGHT", bar, "BOTTOMRIGHT", -2, 2)
    text:SetFont(STANDARD_TEXT_FONT, 9, "THINOUTLINE")
    text:SetJustifyH("CENTER")
    frame.text = text

    -- Create combat feedback text
    local feedback = bar:CreateFontString(guid .. "feedback" .. GetTime(), "OVERLAY", "NumberFontNormalHuge")
    feedback:SetAlpha(0.8)
    feedback:SetFont(DAMAGE_TEXT_FONT, 12, "OUTLINE")
    feedback:SetParent(bar)
    feedback:ClearAllPoints()
    feedback:SetPoint("CENTER", bar, "CENTER", 0, 0)
    frame.feedbackFontHeight = 14
    frame.feedbackStartTime = GetTime()
    frame.feedbackText = feedback

    -- Create raid icon
    local icon = bar:CreateTexture(nil, "OVERLAY")
    icon:SetWidth(12)
    icon:SetHeight(12)
    icon:SetPoint("RIGHT", frame, "RIGHT", -2, 0)
    icon:SetTexture("Interface\\TargetingFrame\\UI-RaidTargetingIcons")
    icon:Hide()
    frame.icon = icon

    -- Create target indicator
    local target_left = bar:CreateTexture(nil, "OVERLAY")
    target_left:SetWidth(8)
    target_left:SetHeight(8)
    target_left:SetPoint("LEFT", frame, "LEFT", -4, 0)
    target_left:SetTexture("Interface\\AddOns\\RunAway\\img\\target-left")
    target_left:Hide()
    frame.target_left = target_left

    local target_right = bar:CreateTexture(nil, "OVERLAY")
    target_right:SetWidth(8)
    target_right:SetHeight(8)
    target_right:SetPoint("RIGHT", frame, "RIGHT", 4, 0)
    target_right:SetTexture("Interface\\AddOns\\RunAway\\img\\target-right")
    target_right:Hide()
    frame.target_right = target_right

    -- Create backdrop
    frame:SetBackdrop(templates.background)
    frame:SetBackdropColor(0, 0, 0, 1)

    local border = CreateFrame("Frame", nil, frame.bar)
    border:SetBackdrop(templates.border)
    border:SetBackdropColor(0.2, 0.2, 0.2, 1)
    border:SetPoint("TOPLEFT", frame.bar, "TOPLEFT", -2, 2)
    border:SetPoint("BOTTOMRIGHT", frame.bar, "BOTTOMRIGHT", 2, -2)
    frame.border = border

    -- Distance text (left side)
    if config.showDistance then
        local distanceText = frame:CreateFontString(nil, "OVERLAY", "GameFontWhite")
        distanceText:SetPoint("RIGHT", frame.bar, "LEFT", -2, 0)
        distanceText:SetJustifyH("RIGHT")
        distanceText:SetFont(STANDARD_TEXT_FONT, 9, "THINOUTLINE")
        frame.distanceText = distanceText
    end

    -- Timer text (right side)
    if config.showTimer then
        local timer = frame:CreateFontString(nil, "OVERLAY", "GameFontWhite")
        timer:SetPoint("LEFT", frame.bar, "RIGHT", 2, 0)
        timer:SetFont(STANDARD_TEXT_FONT, 9, "THINOUTLINE")
        timer:SetTextColor(1, 1, 0.5, 1)
        timer:Hide()
        frame.timer = timer
    end

    return frame
end

ui.BarEnter = function()
    this.border:SetBackdropBorderColor(1, 1, 1, 1)
    this.hover = true

    GameTooltip_SetDefaultAnchor(GameTooltip, this)
    GameTooltip:SetUnit(this.guid)
    GameTooltip:Show()
end

ui.BarLeave = function()
    this.hover = false
    GameTooltip:Hide()
end

-- Pre-defined color strings for distance (avoids string creation in hot path)
local DIST_COLOR_GREY = "|cff888888"
local DIST_COLOR_RED = "|cffff0000"
local DIST_COLOR_ORANGE = "|cffff9900"
local DIST_COLOR_YELLOW = "|cffffff00"
local DIST_COLOR_CYAN = "|cff00ffff"
local DIST_COLOR_GREEN = "|cff00ff00"

ui.BarUpdate = function()
    local guid = this.guid
    if not UnitExists(guid) then
        return
    end

    local bar = this.bar

    -- Update statusbar values
    bar:SetMinMaxValues(0, UnitHealthMax(guid))
    bar:SetValue(UnitHealth(guid))

    -- Update health bar color
    local _, r, g, b = utils.GetUnitColor(guid)
    bar:SetStatusBarColor(r, g, b, 1)

    -- Update caption text
    local level = utils.GetLevelString(guid)
    local level_color = utils.GetLevelColor(guid)
    local name = UnitName(guid)
    this.text:SetText(level_color .. level .. "|r " .. name)

    -- Show raid icon if existing
    local raidIndex = GetRaidTargetIndex(guid)
    local icon = this.icon
    if raidIndex then
        SetRaidTargetIconTexture(icon, raidIndex)
        icon:Show()
    else
        icon:Hide()
    end

    -- Update target indicator
    local isTarget = UnitIsUnit("target", guid)
    local tl, tr = this.target_left, this.target_right
    if isTarget then
        tl:Show()
        tr:Show()
    else
        tl:Hide()
        tr:Hide()
    end

    -- Update distance (if visible)
    local distText = this.distanceText
    if distText then
        local distance, distanceValue = utils.GetDistance(guid)
        local distanceColor
        if distance == "∞" then
            distanceColor = DIST_COLOR_GREY
        elseif distanceValue > 40 then
            distanceColor = DIST_COLOR_RED
        elseif distanceValue > 30 then
            distanceColor = DIST_COLOR_ORANGE
        elseif distanceValue > 10 then
            distanceColor = DIST_COLOR_YELLOW
        elseif distanceValue > 5 then
            distanceColor = DIST_COLOR_CYAN
        else
            distanceColor = DIST_COLOR_GREEN
        end
        distText:SetText(distanceColor .. distance .. "|r")
        distText:Show()
    end

    -- Update timer (if visible)
    local timer = this.timer
    if timer then
        local unit_data = this.unit_data
        local remaining = unit_data and unit_data.remaining_time
        if remaining and remaining > 0 then
            timer:SetText(format("%.1fs", remaining))
            timer:Show()
        else
            timer:Hide()
        end
    end
end

ui.BarClick = function()
    TargetUnit(this.guid)
end

ui.BarEvent = function()
    if arg1 ~= this.guid then
        return
    end
end

-- Process units for a specific column filter
-- Cache parsed filters per column to avoid reparsing every frame
local columnFilterCache = {}

ui.ProcessColumnUnits = function(columnConfig)
    local visible_units = {}
    local filterStr = columnConfig.filter

    -- Use cached filter parts or parse and cache
    local filter_parts = columnFilterCache[filterStr]
    if not filter_parts then
        filter_parts = {}
        local filter_texts = { utils.strsplit(',', filterStr) }
        for _, filter_text in pairs(filter_texts) do
            local name, args = utils.strsplit(':', filter_text)
            filter_parts[name] = args or true
        end
        columnFilterCache[filterStr] = filter_parts
    end

    -- Extract aura filter if present
    local checking_aura_id = filter_parts["aura"]

    local core_guids = RunAway.core.guids
    local timers = ui.timers
    local current_time = GetTime()

    -- Go through all tracked units
    for guid, data in pairs(core_guids) do
        -- Early exit if unit doesn't exist
        if not UnitExists(guid) then
            -- Skip this unit
        else
            -- Cache aura check result to avoid duplicate calls
            local auraExists, auraDuration = false, 0
            if checking_aura_id then
                auraExists, auraDuration = utils.CheckAura(guid, checking_aura_id)
                -- Clean up timer if aura has disappeared
                if not auraExists and timers[guid] and timers[guid][checking_aura_id] then
                    timers[guid][checking_aura_id] = nil
                    -- Clean up empty guid entry
                    local has_timers = false
                    for _ in pairs(timers[guid]) do
                        has_timers = true
                        break
                    end
                    if not has_timers then
                        timers[guid] = nil
                    end
                end
            end

            -- Apply filters
            local should_display = true
            local auraMatched = false
            local matched_aura_id = nil

            for name, args in pairs(filter_parts) do
                local filterFunc = filter[name]
                if filterFunc then
                    if not filterFunc(guid, args) then
                        should_display = false
                        break  -- Early exit on first failed filter
                    end
                    if name == "aura" then
                        auraMatched = true
                        matched_aura_id = args
                    end
                end
            end

            -- Check if unit should be displayed
            if should_display then
                local remaining_time = 0

                -- If aura matched, calculate remaining time (reuse cached aura check)
                if auraMatched and matched_aura_id and auraExists then
                    -- Initialize timer tracking
                    if not timers[guid] then
                        timers[guid] = {}
                    end

                    local timerStart = timers[guid][matched_aura_id]
                    if timerStart then
                        remaining_time = auraDuration - (current_time - timerStart)
                        if remaining_time < 0 then remaining_time = 0 end
                    else
                        timers[guid][matched_aura_id] = current_time
                        remaining_time = auraDuration
                    end
                end

                -- Get distance for sorting
                local _, distanceValue = utils.GetDistance(guid)

                tinsert(visible_units, {
                    guid = guid,
                    last_seen = data.time,
                    remaining_time = remaining_time,
                    distance = distanceValue or 999,
                })
            end
        end
    end

    -- Clean up timers for units no longer tracked
    for guid in pairs(timers) do
        if not core_guids[guid] then
            timers[guid] = nil
        end
    end

    -- Sort if configured (stable sort with configurable order)
    local sortBy = columnConfig.sortBy
    if sortBy then
        local sortAsc = (columnConfig.sortOrder == "asc")

        tsort(visible_units, function(a, b)
            -- Get sort values based on sortBy config
            local aVal, bVal
            if sortBy == "timer" then
                aVal, bVal = a.remaining_time, b.remaining_time
            elseif sortBy == "distance" then
                aVal, bVal = a.distance, b.distance
            else
                return a.guid < b.guid  -- Fallback to guid sort
            end

            -- Primary sort by configured key (use tolerance for stable sorting)
            local diff = aVal - bVal
            if abs(diff) > 0.1 then
                if sortAsc then
                    return aVal < bVal
                else
                    return aVal > bVal
                end
            end
            -- Secondary sort by guid for stability (when values are equal)
            return a.guid < b.guid
        end)
    end

    return visible_units
end

-- Main update loop
ui:SetAllPoints()
ui:SetScript("OnUpdate", function()
    -- Throttle the entire update loop (bars have their own OnUpdate for health)
    local currentTime = GetTime()
    if (currentTime - ui.lastSortUpdate) < ui.sortUpdateInterval then
        return
    end
    ui.lastSortUpdate = currentTime

    -- Check if addon is enabled
    if not RunAway_db.enabled then
        if ui.rootFrame then
            RunAway.core.ResetStatus()
        end
        return
    end

    local isBossCombat = RunAway.core and RunAway.core.isBossCombat or false

    -- If not in boss combat, hide everything
    if not isBossCombat then
        RunAway.core.ResetStatus()
        return
    end

    -- If player left combat (but not dead), stop the monitor
    -- Keep monitor running if player is dead (combat still ongoing for raid)
    if not UnitAffectingCombat("player") and not UnitIsDead("player") then
        RunAway.core.ResetStatus()
        return
    end

    -- Get current boss and its layout
    local currentBoss = ui.GetCurrentBoss()
    if not currentBoss then
        RunAway.core.ResetStatus()
        return
    end

    local layout = RunAway_db.bossLayouts[currentBoss]
    if not layout then
        return
    end

    -- Create root frame if not exists (only once)
    if not ui.rootFrame then
        ui.rootFrame = ui.CreateRoot()
        -- Check for saved position (single position for all bosses)
        local savedPos = RunAway_db.framePosition
        if savedPos then
            ui.rootFrame:SetPoint(savedPos.anchor, savedPos.x, savedPos.y)
        else
            ui.rootFrame:SetPoint("CENTER", 0, 0)
        end
    end

    -- Detect boss change - clear columns and rebuild
    if ui.currentBossName ~= currentBoss then
        ui.ClearColumns()
        ui.currentBossName = currentBoss
        -- Update title to show current boss
        ui.rootFrame.caption:SetText(currentBoss)
    end

    -- Apply scale from layout
    ui.rootFrame:SetScale(layout.scale or 1)
    ui.rootFrame:Show()

    -- Skip if locked (during drag)
    if ui.rootFrame.lock then
        return
    end

    -- Process each column (throttling is done at the start of OnUpdate)
    local totalWidth = 0
    local maxHeight = 0
    local titleHeight = 20
    local columnSpacing = 10
    local activeColumnIndex = 0  -- Track actual column position

    for colIndex, columnConfig in ipairs(layout.columns) do
        -- Skip disabled columns
        if columnConfig.enabled == false then
            -- Hide the column if it exists
            if ui.rootFrame.columns[colIndex] then
                ui.rootFrame.columns[colIndex]:Hide()
            end
        else
            activeColumnIndex = activeColumnIndex + 1

            -- Create column if not exists
            if not ui.rootFrame.columns[colIndex] then
                ui.rootFrame.columns[colIndex] = ui.CreateColumn(ui.rootFrame, columnConfig, colIndex)
            end

            local column = ui.rootFrame.columns[colIndex]

            -- Get visible units for this column
            local visible_units = ui.ProcessColumnUnits(columnConfig)

            -- Position and display bars
            local y = titleHeight
            local barCount = 0

            for _, unit_data in ipairs(visible_units) do
                local guid = unit_data.guid
                barCount = barCount + 1

                if barCount > columnConfig.maxrow then
                    break
                end

                -- Create bar if needed
                if not column.bars[guid] then
                    column.bars[guid] = ui.CreateBar(column, guid, unit_data, columnConfig)
                else
                    column.bars[guid].unit_data = unit_data
                end

                local bar = column.bars[guid]

                -- Position bar based on column alignment
                bar:ClearAllPoints()
                local alignment = columnConfig.alignment or "left"
                if alignment == "right" then
                    bar:SetPoint("TOPRIGHT", column, "TOPRIGHT", 0, -y)
                elseif alignment == "center" then
                    bar:SetPoint("TOP", column, "TOP", 0, -y)
                else
                    bar:SetPoint("TOPLEFT", column, "TOPLEFT", 0, -y)
                end
                bar:Show()

                y = y + columnConfig.height + columnConfig.spacing
            end

            -- Hide unused bars
            for guid, bar in pairs(column.bars) do
                local found = false
                for _, unit_data in ipairs(visible_units) do
                    if unit_data.guid == guid then
                        found = true
                        break
                    end
                end
                if not found then
                    bar:Hide()
                    column.bars[guid] = nil
                end
            end

            -- Calculate extra width needed for distance text (left) and timer text (right)
            local extraWidth = 0
            if columnConfig.showDistance then
                extraWidth = extraWidth + 30
            end
            if columnConfig.showTimer then
                extraWidth = extraWidth + 30
            end

            -- Update column size and position with extra width
            local columnHeight = math.max(y, titleHeight + columnConfig.height)
            local actualColumnWidth = columnConfig.width + extraWidth
            column:SetWidth(actualColumnWidth)
            column:SetHeight(columnHeight)

            -- Position column
            column:ClearAllPoints()
            column:SetPoint("TOPLEFT", ui.rootFrame, "TOPLEFT", totalWidth, -titleHeight)
            column:Show()

            -- Update total width for root frame calculation
            totalWidth = totalWidth + actualColumnWidth + columnSpacing
            maxHeight = math.max(maxHeight, columnHeight)
        end
    end

    -- Update root frame size
    ui.rootFrame:SetWidth(math.max(totalWidth, 100))
    ui.rootFrame:SetHeight(maxHeight + titleHeight + 10)
end)

RunAway.ui = ui
