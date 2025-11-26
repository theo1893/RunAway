if RunAway.disabled then
    return
end

local utils = RunAway.utils
local filter = RunAway.filter
local settings = RunAway.settings

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

ui.frames = {}
ui.timers = {}

ui.CreateRoot = function(parent, caption)
    local frame = CreateFrame("Frame", "RunAway" .. caption, parent)
    frame.id = caption

    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetMovable(true)

    frame:SetScript("OnDragStart", function()
        this.lock = true
        this:StartMoving()
    end)

    frame:SetScript("OnDragStop", function()
        -- load current window config
        local config = RunAway_db.config[this.id]

        -- convert to best anchor depending on position
        local new_anchor = utils.GetBestAnchor(this)
        local anchor, x, y = utils.ConvertFrameAnchor(this, new_anchor)
        this:ClearAllPoints()
        this:SetPoint(anchor, UIParent, anchor, x, y)

        -- save new position
        local anchor, _, _, x, y = this:GetPoint()
        config.anchor, config.x, config.y = anchor, x, y

        -- stop drag
        this:StopMovingOrSizing()
        this.lock = false
    end)

    -- assign/initialize elements
    frame.CreateBar = ui.CreateBar
    frame.frames = {}

    -- create title text
    frame.caption = frame:CreateFontString(nil, "HIGH", "GameFontWhite")
    frame.caption:SetFont(STANDARD_TEXT_FONT, 9, "THINOUTLINE")
    frame.caption:SetPoint("TOPLEFT", frame, "TOPLEFT", 10, -2)
    frame.caption:SetTextColor(1, 1, 1, 1)
    frame.caption:SetText(caption)

    -- create option button
    frame.settings = CreateFrame("Button", nil, frame)
    frame.settings:SetPoint("RIGHT", frame.caption, "LEFT", -2, 0)
    frame.settings:SetWidth(8)
    frame.settings:SetHeight(8)

    frame.settings:SetScript("OnEnter", function()
        frame.settings.tex:SetAlpha(1)
    end)

    frame.settings:SetScript("OnLeave", function()
        frame.settings.tex:SetAlpha(.5)
    end)

    frame.settings.tex = frame.settings:CreateTexture(nil, 'OVERLAY')
    frame.settings.tex:SetTexture("Interface\\AddOns\\RunAway\\img\\config")
    frame.settings.tex:SetAllPoints()
    frame.settings.tex:SetAlpha(.5)

    frame.settings:SetScript("OnClick", function()
        settings.OpenConfig(this:GetParent().id)
    end)

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
    -- animate combat text
    CombatFeedback_OnUpdate(arg1)

    -- update statusbar values
    this.bar:SetMinMaxValues(0, UnitHealthMax(this.guid))
    this.bar:SetValue(UnitHealth(this.guid))

    -- update health bar color
    local hex, r, g, b, a = utils.GetUnitColor(this.guid)
    this.bar:SetStatusBarColor(r, g, b, a)

    -- update caption text
    local level = utils.GetLevelString(this.guid)
    local level_color = utils.GetLevelColor(this.guid)
    local name = UnitName(this.guid)
    this.text:SetText(level_color .. level .. "|r " .. name)

    -- update health bar border
    if this.hover then
        this.border:SetBackdropBorderColor(1, 1, 1, 1)
    elseif UnitAffectingCombat(this.guid) then
        this.border:SetBackdropBorderColor(.8, .2, .2, 1)
    else
        this.border:SetBackdropBorderColor(.2, .2, .2, 1)
    end

    -- show raid icon if existing
    if GetRaidTargetIndex(this.guid) then
        SetRaidTargetIconTexture(this.icon, GetRaidTargetIndex(this.guid))
        this.icon:Show()
    else
        this.icon:Hide()
    end

    -- update target indicator
    if UnitIsUnit("target", this.guid) then
        this.target_left:Show()
        this.target_right:Show()
    else
        this.target_left:Hide()
        this.target_right:Hide()
    end

    -- 根据距离区分颜色
    local distance, distanceValue = utils.GetDistance(this.guid)
    if distance == "∞" then
        distanceColor = "|cff888888" -- 无限远显示灰色
    elseif distanceValue > 40 then
        distanceColor = "|cffff0000" -- 红色：>40码
    elseif distanceValue > 30 then
        distanceColor = "|cffff9900" -- 橙色：30<距离≤40
    elseif distanceValue > 10 then
        distanceColor = "|cffffff00" -- 黄色：10<距离≤30
    elseif distanceValue > 5 then
        distanceColor = "|cff00ffff" -- 青色：5<距离≤10
    else
        distanceColor = "|cff00ff00" -- 蓝色：≤5码
    end

    this.distanceText:SetText(string.format("%s（%s）|r", distanceColor, distance))
    this.distanceText:Show()

    -- 默认隐藏timer
    this.timer:Hide()

    -- Use pre-calculated remaining_time from unit_data (updated every 0.5s in main loop)
    -- This avoids redundant config parsing, CheckAura calls, and timer structure management
    if this.unit_data and this.unit_data.remaining_time and this.unit_data.remaining_time > 0 then
        this.timer:SetText(string.format("%.1f", this.unit_data.remaining_time))
        this.timer:Show()
    end
end

ui.BarClick = function()
    TargetUnit(this.guid)
end

ui.BarEvent = function()
    if arg1 ~= this.guid then
        return
    end
    CombatFeedback_OnCombatEvent(arg2, arg3, arg4, arg5)
end

ui.CreateBar = function(parent, guid, unit_data)
    local frame = CreateFrame("Button", nil, parent)
    frame.guid = guid

    -- Store pre-calculated data for use by OnUpdate
    frame.unit_data = unit_data or {}

    -- assign required events and scripts
    frame:RegisterEvent("UNIT_COMBAT")
    frame:SetScript("OnEvent", ui.BarEvent)
    frame:SetScript("OnClick", ui.BarClick)
    frame:SetScript("OnEnter", ui.BarEnter)
    frame:SetScript("OnLeave", ui.BarLeave)
    frame:SetScript("OnUpdate", ui.BarUpdate)

    -- create health bar
    local bar = CreateFrame("StatusBar", nil, frame)
    bar:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
    bar:SetStatusBarColor(1, .8, .2, 1)
    bar:SetMinMaxValues(0, 100)
    bar:SetValue(20)
    bar:SetAllPoints()
    frame.bar = bar

    -- create caption text
    local text = frame.bar:CreateFontString(nil, "HIGH", "GameFontWhite")
    text:SetPoint("TOPLEFT", bar, "TOPLEFT", 2, -2)
    text:SetPoint("BOTTOMRIGHT", bar, "BOTTOMRIGHT", -30, 2)  -- Leave space for timer (30px)
    text:SetFont(STANDARD_TEXT_FONT, 9, "THINOUTLINE")
    text:SetJustifyH("LEFT")
    frame.text = text

    -- create combat feedback text
    local feedback = bar:CreateFontString(guid .. "feedback" .. GetTime(), "OVERLAY", "NumberFontNormalHuge")
    feedback:SetAlpha(.8)
    feedback:SetFont(DAMAGE_TEXT_FONT, 12, "OUTLINE")
    feedback:SetParent(bar)
    feedback:ClearAllPoints()
    feedback:SetPoint("CENTER", bar, "CENTER", 0, 0)

    frame.feedbackFontHeight = 14
    frame.feedbackStartTime = GetTime()
    frame.feedbackText = feedback

    -- create raid icon textures
    local icon = bar:CreateTexture(nil, "OVERLAY")
    icon:SetWidth(16)
    icon:SetHeight(16)
    icon:SetPoint("RIGHT", frame, "RIGHT", -2, 0)
    icon:SetTexture("Interface\\TargetingFrame\\UI-RaidTargetingIcons")
    icon:Hide()
    frame.icon = icon

    -- create target indicator
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

    -- create frame backdrops
    if pfUI and pfUI.uf then
        pfUI.api.CreateBackdrop(frame)
        frame.border = frame.backdrop
    else
        frame:SetBackdrop(ui.background)
        frame:SetBackdropColor(0, 0, 0, 1)

        local border = CreateFrame("Frame", nil, frame.bar)
        border:SetBackdrop(ui.border)
        border:SetBackdropColor(.2, .2, .2, 1)
        border:SetPoint("TOPLEFT", frame.bar, "TOPLEFT", -2, 2)
        border:SetPoint("BOTTOMRIGHT", frame.bar, "BOTTOMRIGHT", 2, -2)
        frame.border = border
    end

    -- add timer text
    local timer = frame.bar:CreateFontString(nil, "OVERLAY", "GameFontWhite")
    timer:SetPoint("LEFT", frame.bar, "RIGHT", 2, 0)  -- Position completely to the right of the bar (no overlap)
    timer:SetFont(STANDARD_TEXT_FONT, 9, "THINOUTLINE")
    timer:SetTextColor(1, 1, 0.5, 1)
    timer:Hide()
    frame.timer = timer

    local distanceText = frame:CreateFontString(nil, "OVERLAY", "GameFontWhite")
    distanceText:SetPoint("RIGHT", frame.bar, "LEFT", -2, 0)  -- Position to the left of the bar with minimal spacing
    distanceText:SetJustifyH("RIGHT")  -- Align text right so it doesn't overlap the bar
    distanceText:SetFont(STANDARD_TEXT_FONT, 9, "THINOUTLINE")
    --distanceText:SetTextColor(1, 1, 1, 1)  -- Set white color for distance text
    frame.distanceText = distanceText

    return frame
end

ui:SetAllPoints()
ui:SetScript("OnUpdate", function()
    if (this.tick or 1) > GetTime() then
        return
    else
        this.tick = GetTime() + .5
    end

    -- remove old leftover frames
    for caption, root in pairs(ui.frames) do
        if not RunAway_db.config[caption] then
            ui.frames[caption]:Hide()
            ui.frames[caption] = nil
        end
    end

    -- create ui frames based on config values
    for caption, config in pairs(RunAway_db.config) do
        -- create root frame if not existing
        ui.frames[caption] = ui.frames[caption] or ui:CreateRoot(caption)
        local root = ui.frames[caption]

        -- skip if locked (due to moving)
        if root.lock then
            return
        end

        -- update position based on config
        if not root.pos or root.pos ~= config.anchor .. config.x .. config.y .. config.scale then
            root.pos = config.anchor .. config.x .. config.y .. config.scale
            root:ClearAllPoints()
            root:SetPoint(config.anchor, config.x, config.y)
            root:SetScale(config.scale)
        end

        -- update filter if required
        if not root.filter_conf or root.filter_conf ~= config.filter then
            root.filter = {}

            -- prepare all filter texts
            local filter_texts = { utils.strsplit(',', config.filter) }
            for id, filter_text in pairs(filter_texts) do
                local name, args = utils.strsplit(':', filter_text)
                root.filter[name] = args or true
            end

            -- mark current state of data
            root.filter_conf = config.filter
        end

        -- run through all guids and fill with bars
        local title_size = 12 + config.spacing
        local width, height = config.width, config.height + title_size
        local x, y, count = 0, 0, 0

        -- collect visible units with their remaining bandage time
        local visible_units = {}

        for guid, data in pairs(RunAway.core.guids) do
            -- apply filters
            local visible = true
            local auraMatched = false
            local matched_aura_id = nil
            for name, args in pairs(root.filter) do
                if filter[name] then
                    visible = visible and filter[name](guid, args)

                    -- 命中aura，保存aura identifier
                    if visible and name == "aura" then
                        auraMatched = true
                        matched_aura_id = args
                    end
                end
            end

            -- check if unit exists and is visible
            if UnitExists(guid) and visible then
                -- 如果aura命中，使用三层映射维护 guid -> aura -> timer
                if auraMatched and matched_aura_id then
                    local remaining_time = 0
                    local current_time = GetTime()

                    -- 检查aura是否存在并获取duration
                    local exist, total_duration = utils.CheckAura(guid, matched_aura_id)

                    if exist then
                        -- 初始化三层嵌套结构
                        if not ui.timers[guid] then
                            ui.timers[guid] = {}
                        end

                        -- 维护guid -> aura -> timer的映射
                        if ui.timers[guid][matched_aura_id] then
                            remaining_time = total_duration - (current_time - ui.timers[guid][matched_aura_id])
                            remaining_time = math.max(0, remaining_time)
                        else
                            -- 新检测到的aura，开始追踪
                            ui.timers[guid][matched_aura_id] = current_time
                            remaining_time = total_duration
                        end

                        -- add to visible units table
                        table.insert(visible_units, {
                            guid = guid,
                            last_seen = data.time,
                            remaining_time = remaining_time,
                        })
                    else
                        -- aura不再存在，清理timer
                        if ui.timers[guid] and ui.timers[guid][matched_aura_id] then
                            ui.timers[guid][matched_aura_id] = nil
                            -- 清理空的guid条目
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
                else
                    -- 未命中aura, 但是需要展示, 则简单添加仅table
                    table.insert(visible_units, {
                        guid = guid,
                        last_seen = data.time,
                        remaining_time = 0,
                    })
                end
            end
        end

        -- 清理不再被追踪的单位的timer
        for guid in pairs(ui.timers) do
            if not RunAway.core.guids[guid] then
                ui.timers[guid] = nil
            end
        end

        -- sort visible units
        table.sort(visible_units, function(a, b)
            return a.remaining_time > b.remaining_time
        end)

        -- now display the sorted units
        for _, unit_data in ipairs(visible_units) do
            local guid = unit_data.guid
            count = count + 1

            if count > config.maxrow then
                count, x = 1, x + config.width + config.spacing
                width = math.max(x + config.width, width)
            end

            y = (count - 1) * (config.height + config.spacing) + title_size
            height = math.max(y + config.height + config.spacing, height)

            -- Create bar if needed, passing unit_data
            if not root.frames[guid] then
                root.frames[guid] = root:CreateBar(guid, unit_data)
            else
                -- Update existing bar's unit_data
                root.frames[guid].unit_data = unit_data
            end

            -- update position if required
            if not root.frames[guid].pos or root.frames[guid].pos ~= x .. -y then
                root.frames[guid]:ClearAllPoints()
                root.frames[guid]:SetPoint("TOPLEFT", root, "TOPLEFT", x, -y)
                root.frames[guid].pos = x .. -y
            end

            -- update sizes if required
            if not root.frames[guid].sizes or root.frames[guid].sizes ~= config.width .. config.height then
                root.frames[guid]:SetWidth(config.width)
                root.frames[guid]:SetHeight(config.height)
                root.frames[guid].sizes = config.width .. config.height
            end

            root.frames[guid]:Show()
        end

        -- hide unused frames that are no longer visible
        -- create a set of visible guids for quick lookup
        local visible_guids = {}
        for _, unit_data in ipairs(visible_units) do
            visible_guids[unit_data.guid] = true
        end

        -- hide frames not in the visible list
        for guid, frame in pairs(root.frames) do
            if not visible_guids[guid] then
                frame:Hide()
                root.frames[guid] = nil
            end
        end

        -- update window size
        root:SetWidth(width)
        root:SetHeight(height)
    end
end)

RunAway.ui = ui
