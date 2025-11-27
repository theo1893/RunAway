if RunAway.disabled then
    return
end
local utils = RunAway.utils
local core = CreateFrame("Frame", nil, WorldFrame)

core.guids = {}

-- Boss combat tracking variables
core.isBossCombat = false
core.currentBosses = {}

-- Check if a boss has any enabled columns
core.HasEnabledColumns = function(bossName)
    local layout = RunAway_db.bossLayouts and RunAway_db.bossLayouts[bossName]
    if not layout or not layout.columns then
        return false
    end

    for _, column in ipairs(layout.columns) do
        -- Default to enabled if not set
        if column.enabled == nil or column.enabled == true then
            return true
        end
    end

    return false
end

-- Check if a unit is a boss (derives from bossLayouts config)
-- Returns false if all columns are disabled for this boss
core.IsBossUnit = function(unit)
    if not UnitExists(unit) then
        return false
    end

    local unitName = UnitName(unit)
    if unitName and RunAway_db.bossLayouts and RunAway_db.bossLayouts[unitName] then
        -- Check if any columns are enabled for this boss
        if core.HasEnabledColumns(unitName) then
            return true
        end
    end

    return false
end

-- Reset all status for boss combat and UI
core.ResetStatus = function()
    -- Core status reset
    core.guids = {}
    core.isBossCombat = false

    -- Clear all current bosses
    for guid in pairs(core.currentBosses) do
        core.currentBosses[guid] = false
    end

    -- UI status reset
    if RunAway.ui then
        -- Clear UI timers
        RunAway.ui.timers = {}

        -- Clear root frame completely (not just hide)
        if RunAway.ui.rootFrame then
            -- Hide the frame first
            RunAway.ui.rootFrame:Hide()

            -- Clear and delete all bars and columns
            if RunAway.ui.rootFrame.columns then
                for _, column in pairs(RunAway.ui.rootFrame.columns) do
                    if column.bars then
                        for bar_guid, bar in pairs(column.bars) do
                            bar:Hide()
                            bar = nil  -- Clear bar reference
                            column.bars[bar_guid] = nil  -- Remove from column bars
                        end
                        column.bars = nil  -- Clear bars table
                    end
                    column:Hide()
                    column = nil  -- Clear column reference
                end
                RunAway.ui.rootFrame.columns = nil  -- Clear columns table
            end

            -- Delete the root frame itself
            RunAway.ui.rootFrame:ClearAllPoints()
            RunAway.ui.rootFrame = nil  -- Remove root frame reference
        end
    end
end

core.add = function(unit)
    -- Skip if addon is disabled
    if not RunAway_db.enabled then
        return
    end

    local exists, guid = UnitExists(unit)
    if not exists or not guid then
        if core.guids[guid] then
            core.guids[guid] = nil
        end
        return
    end

    local _, distanceValue = utils.GetDistance(unit)

    -- Check if this unit is a boss
    local isBoss = core.IsBossUnit(unit)

    -- Only add unit if we're already in boss combat or this unit is a boss
    if not core.isBossCombat and not isBoss then
        --print("not in boss combat. current unit count is ", utils.CountTable(core.guids))
        return
    end

    --print("in boss combat. current unit count is ", utils.CountTable(core.guids))
    -- If this is a boss unit, manage boss combat state
    if isBoss and distanceValue < 100 then
        local isDead = UnitIsDead(unit)
        if isDead then
            -- Boss died - reset all status
            core.ResetStatus()
            return
        else
            -- Boss is alive - enter boss combat mode
            core.isBossCombat = true
            core.currentBosses[guid] = true
        end
    end

    -- Track all units during boss combat (no GUID limit)
    core.guids[guid] = { time = GetTime(), distance = distanceValue }
end

-- unitstr
--core:RegisterEvent("UPDATE_MOUSEOVER_UNIT")
--core:RegisterEvent("PLAYER_TARGET_CHANGED")
core:RegisterEvent("PLAYER_ENTERING_WORLD")

-- arg1
core:RegisterEvent("UNIT_COMBAT")
--core:RegisterEvent("UNIT_HAPPINESS")
core:RegisterEvent("UNIT_MODEL_CHANGED")
core:RegisterEvent("UNIT_PORTRAIT_UPDATE")
core:RegisterEvent("UNIT_FACTION")
core:RegisterEvent("UNIT_FLAGS")
core:RegisterEvent("UNIT_AURA")
core:RegisterEvent("UNIT_HEALTH")
core:RegisterEvent("UNIT_MANA")
core:RegisterEvent("UNIT_CASTEVENT")

core:SetScript("OnEvent", function()
    if event == "UPDATE_MOUSEOVER_UNIT" then
        this.add("mouseover")
    elseif event == "PLAYER_ENTERING_WORLD" then
        this.add("player")
    elseif event == "PLAYER_TARGET_CHANGED" then
        this.add("target")
    else
        this.add(arg1)
    end
end)

RunAway.core = core
