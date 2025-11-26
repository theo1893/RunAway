if RunAway.disabled then
    return
end

local utils = RunAway.utils
local filter = RunAway.filter

local ui = CreateFrame("Frame", nil, UIParent)

ui.border = {
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    tile = true, tileSize = 16, edgeSize = 8,
    insets = { left = 2, right = 2, top = 2, bottom = 2 }
}

ui.background = {
    bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
    tile = true, tileSize = 16, edgeSize = 8,
    insets = { left = 0, right = 0, top = 0, bottom = 0 }
}

ui.rootFrame = nil
ui.timers = {}

-- Boss-specific layout definitions
ui.bossLayouts = {
    ["阿诺玛鲁斯"] = {
        name = "阿诺玛鲁斯",
        anchor = "CENTER",
        x = 0,
        y = 0,
        scale = 1.2,
        columns = {
            {
                title = "炸弹",
                filter = "aura:arcaneoverload",
                width = 120,
                height = 14,
                spacing = 4,
                maxrow = 20,
                showDistance = true,
                showTimer = false,
                sortByTimer = false,
                alignment = "right", -- Align bars to the right
                colors = {
                    bgColor = { 0.3, 0.1, 0.1, 0.9 }, -- Redish background
                    borderColor = { 1, 0.2, 0.2, 1 }, -- Red border
                    titleColor = { 1, 0.4, 0.4, 1 }        -- Light red title
                }
            },
            {
                title = "踩圈",
                filter = "aura:arcanedampening",
                width = 120,
                height = 14,
                spacing = 4,
                maxrow = 20,
                showDistance = true,
                showTimer = true,
                sortByTimer = true,
                alignment = "center", -- Align bars to the center
                colors = {
                    bgColor = { 0.1, 0.2, 0.1, 0.9 }, -- Green background
                    borderColor = { 0.2, 0.8, 0.2, 1 }, -- Green border
                    titleColor = { 0.4, 1, 0.4, 1 }        -- Light green title
                }
            }
        }
    },
    ["老杂斑野猪"] = {
        name = "老杂斑野猪",
        anchor = "CENTER",
        x = 0,
        y = 0,
        scale = 1.2,
        columns = {
            {
                title = "绷带",
                filter = "aura:bandage",
                width = 120,
                height = 14,
                spacing = 4,
                maxrow = 20,
                showDistance = true,
                showTimer = true,
                sortByTimer = true,
                alignment = "center", -- Align bars to the center
                colors = {
                    bgColor = { 0.1, 0.2, 0.1, 0.9 }, -- Green background
                    borderColor = { 0.2, 0.8, 0.2, 1 }, -- Green border
                    titleColor = { 0.4, 1, 0.4, 1 }        -- Light green title
                }
            }
        }
    },
}

-- Get current boss name from detected bosses
ui.GetCurrentBoss = function()
    if not RunAway.core or not RunAway.core.currentBosses then
        return nil
    end

    for guid, active in pairs(RunAway.core.currentBosses) do
        if active and UnitExists(guid) then
            local bossName = UnitName(guid)
            if ui.bossLayouts[bossName] then
                return bossName
            end
        end
    end

    return nil
end

-- Create the root frame with title
ui.CreateRoot = function(layoutName)
    local frame = CreateFrame("Frame", "RunAway" .. layoutName, UIParent)

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
    end)

    frame:SetBackdrop(ui.background)
    frame:SetBackdropColor(0.1, 0.1, 0.1, 0.9)

    -- Create border
    local border = CreateFrame("Frame", nil, frame)
    border:SetBackdrop(ui.border)
    border:SetBackdropBorderColor(0.4, 0.4, 0.4, 1)
    border:SetPoint("TOPLEFT", frame, "TOPLEFT", -2, 2)
    border:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 2, -2)
    frame.border = border

    -- Create title text
    frame.caption = frame:CreateFontString(nil, "HIGH", "GameFontWhite")
    frame.caption:SetFont(STANDARD_TEXT_FONT, 10, "THINOUTLINE")
    frame.caption:SetPoint("TOP", frame, "TOP", 0, -4)
    frame.caption:SetTextColor(1, 1, 0, 1)
    frame.caption:SetText(layoutName)

    frame.columns = {}

    return frame
end

-- Create a column frame
ui.CreateColumn = function(parent, columnConfig, columnIndex)
    local column = CreateFrame("Frame", nil, parent)
    column.config = columnConfig
    column.index = columnIndex
    column.bars = {}

    -- Set column background
    column:SetBackdrop(ui.background)
    if columnConfig.colors and columnConfig.colors.bgColor then
        column:SetBackdropColor(unpack(columnConfig.colors.bgColor))
    end

    -- Create column border with custom color
    local border = CreateFrame("Frame", nil, column)
    border:SetBackdrop(ui.border)
    border:SetPoint("TOPLEFT", column, "TOPLEFT", -2, 2)
    border:SetPoint("BOTTOMRIGHT", column, "BOTTOMRIGHT", 2, -2)

    if columnConfig.colors and columnConfig.colors.borderColor then
        border:SetBackdropBorderColor(unpack(columnConfig.colors.borderColor))
    end

    column.border = border

    -- Create column title with custom color
    column.title = column:CreateFontString(nil, "HIGH", "GameFontWhite")
    column.title:SetFont(STANDARD_TEXT_FONT, 9, "THINOUTLINE")
    column.title:SetPoint("TOP", column, "TOP", 0, -2)
    if columnConfig.colors and columnConfig.colors.titleColor then
        column.title:SetTextColor(unpack(columnConfig.colors.titleColor))
    end
    column.title:SetText(columnConfig.title or "Column " .. columnIndex)

    return column
end

-- Create a unit bar (simplified version)
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
    frame:SetBackdrop(ui.background)
    frame:SetBackdropColor(0, 0, 0, 1)

    local border = CreateFrame("Frame", nil, frame.bar)
    border:SetBackdrop(ui.border)
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

ui.BarUpdate = function()
    -- Animate combat text
    --CombatFeedback_OnUpdate(arg1)

    if not UnitExists(this.guid) then
        return
    end

    -- Update statusbar values
    this.bar:SetMinMaxValues(0, UnitHealthMax(this.guid))
    this.bar:SetValue(UnitHealth(this.guid))

    -- Update health bar color
    local hex, r, g, b, a = utils.GetUnitColor(this.guid)
    this.bar:SetStatusBarColor(r, g, b, a)

    -- Update caption text
    local level = utils.GetLevelString(this.guid)
    local level_color = utils.GetLevelColor(this.guid)
    local name = UnitName(this.guid)
    this.text:SetText(level_color .. level .. "|r " .. name)

    ---- Update health bar border
    --if this.hover then
    --    this.border:SetBackdropBorderColor(1, 1, 1, 1)
    --elseif UnitAffectingCombat(this.guid) then
    --    this.border:SetBackdropBorderColor(0.8, 0.2, 0.2, 1)
    --else
    --    this.border:SetBackdropBorderColor(0.2, 0.2, 0.2, 1)
    --end

    -- Show raid icon if existing
    if GetRaidTargetIndex(this.guid) then
        SetRaidTargetIconTexture(this.icon, GetRaidTargetIndex(this.guid))
        this.icon:Show()
    else
        this.icon:Hide()
    end

    -- Update target indicator
    if UnitIsUnit("target", this.guid) then
        this.target_left:Show()
        this.target_right:Show()
    else
        this.target_left:Hide()
        this.target_right:Hide()
    end

    -- Update distance (if visible)
    if this.distanceText then
        local distance, distanceValue = utils.GetDistance(this.guid)
        local distanceColor
        if distance == "∞" then
            distanceColor = "|cff888888"
        elseif distanceValue > 40 then
            distanceColor = "|cffff0000"
        elseif distanceValue > 30 then
            distanceColor = "|cffff9900"
        elseif distanceValue > 10 then
            distanceColor = "|cffffff00"
        elseif distanceValue > 5 then
            distanceColor = "|cff00ffff"
        else
            distanceColor = "|cff00ff00"
        end
        this.distanceText:SetText(string.format("%s%s|r", distanceColor, distance))
        this.distanceText:Show()
    end

    -- Update timer (if visible)
    if this.timer then
        if this.unit_data and this.unit_data.remaining_time and this.unit_data.remaining_time > 0 then
            this.timer:SetText(string.format("%.1fs", this.unit_data.remaining_time))
            this.timer:Show()
        else
            this.timer:Hide()
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
    --CombatFeedback_OnCombatEvent(arg2, arg3, arg4, arg5)
end

-- Process units for a specific column filter
ui.ProcessColumnUnits = function(columnConfig)
    local visible_units = {}

    -- Parse filter
    local filter_parts = {}
    local filter_texts = { utils.strsplit(',', columnConfig.filter) }
    for id, filter_text in pairs(filter_texts) do
        local name, args = utils.strsplit(':', filter_text)
        filter_parts[name] = args or true
    end

    -- Extract aura filter if present
    local checking_aura_id = filter_parts["aura"]

    -- Go through all tracked units
    for guid, data in pairs(RunAway.core.guids) do
        -- Clean up this column's aura timer if unit doesn't have it anymore
        if checking_aura_id and UnitExists(guid) then
            local exist = utils.CheckAura(guid, checking_aura_id)
            if not exist and ui.timers[guid] and ui.timers[guid][checking_aura_id] then
                ui.timers[guid][checking_aura_id] = nil
                -- Clean up empty guid entry
                local has_timers = false
                for _ in pairs(ui.timers[guid]) do
                    has_timers = true
                    break
                end
                if not has_timers then
                    ui.timers[guid] = nil
                end
            end
        end

        -- Apply filters
        local should_display = true
        local auraMatched = false
        local matched_aura_id = nil

        for name, args in pairs(filter_parts) do
            if filter[name] then
                should_display = should_display and filter[name](guid, args)

                if should_display and name == "aura" then
                    auraMatched = true
                    matched_aura_id = args
                end
            end
        end

        -- Check if unit exists and should be displayed
        if UnitExists(guid) and should_display then
            local remaining_time = 0

            -- If aura matched, calculate remaining time
            if auraMatched and matched_aura_id then
                local current_time = GetTime()
                local exist, total_duration = utils.CheckAura(guid, matched_aura_id)

                if exist then
                    -- Initialize timer tracking
                    if not ui.timers[guid] then
                        ui.timers[guid] = {}
                    end

                    if ui.timers[guid][matched_aura_id] then
                        remaining_time = total_duration - (current_time - ui.timers[guid][matched_aura_id])
                        remaining_time = math.max(0, remaining_time)
                    else
                        ui.timers[guid][matched_aura_id] = current_time
                        remaining_time = total_duration
                    end
                end
            end

            table.insert(visible_units, {
                guid = guid,
                last_seen = data.time,
                remaining_time = remaining_time,
            })
        end
    end

    -- Clean up timers for units no longer tracked
    for guid in pairs(ui.timers) do
        if not RunAway.core.guids[guid] then
            ui.timers[guid] = nil
        end
    end

    -- Sort by remaining time if requested
    if columnConfig.sortByTimer then
        table.sort(visible_units, function(a, b)
            return a.remaining_time > b.remaining_time
        end)
    end

    return visible_units
end

-- Main update loop
ui:SetAllPoints()
ui:SetScript("OnUpdate", function()
    local isBossCombat = RunAway.core and RunAway.core.isBossCombat or false

    -- If not in boss combat, hide everything
    if not isBossCombat then
        --if ui.rootFrame then
        --    ui.rootFrame:Hide()
        --end
        RunAway.core.ResetStatus()
        return
    end

    -- Get current boss and its layout
    local currentBoss = ui.GetCurrentBoss()
    if not currentBoss then
        --if ui.rootFrame then
        --    ui.rootFrame:Hide()
        --end
        RunAway.core.ResetStatus()
        return
    end

    local layout = ui.bossLayouts[currentBoss]
    if not layout then
        return
    end

    -- Create root frame if not exists
    if not ui.rootFrame then
        ui.rootFrame = ui.CreateRoot(layout.name)
        ui.rootFrame:SetPoint(layout.anchor, layout.x, layout.y)
        ui.rootFrame:SetScale(layout.scale)
    end

    ui.rootFrame:Show()

    -- Skip if locked (during drag)
    if ui.rootFrame.lock then
        return
    end

    -- Process each column
    local totalWidth = 0
    local maxHeight = 0
    local titleHeight = 20
    local columnSpacing = 10

    for colIndex, columnConfig in ipairs(layout.columns) do
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
            local alignment = columnConfig.alignment or "left"  -- Default to left alignment if not specified
            if alignment == "right" then
                bar:SetPoint("TOPRIGHT", column, "TOPRIGHT", 0, -y)
            elseif alignment == "center" then
                bar:SetPoint("TOP", column, "TOP", 0, -y)  -- TOP anchor centers the bar horizontally
            else
                bar:SetPoint("TOPLEFT", column, "TOPLEFT", 0, -y)  -- Default to left alignment
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
            extraWidth = extraWidth + 30-- Estimated width for distance display like ">28" or "12.3"
        end
        if columnConfig.showTimer then
            extraWidth = extraWidth + 30 -- Estimated width for timer display like "12.3s"
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

    -- Update root frame size
    ui.rootFrame:SetWidth(totalWidth)
    ui.rootFrame:SetHeight(maxHeight + titleHeight + 10)
end)

RunAway.ui = ui
