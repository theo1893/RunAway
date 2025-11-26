if RunAway.disabled then
    return
end
local utils = RunAway.utils
local core = CreateFrame("Frame", nil, WorldFrame)

core.guids = {}

-- Boss combat tracking variables
core.isBossCombat = false
core.currentBosses = {}

-- Boss names (configurable list)
core.bossNames = {
    ["Ragnaros"] = true,
    ["Nefarian"] = true,
    ["Onyxia"] = true,
    ["老杂斑野猪"] = true
}

-- Check if a unit is a boss
core.IsBossUnit = function(unit)
    if not UnitExists(unit) then
        return false
    end

    -- Check by name
    local unitName = UnitName(unit)
    if unitName and core.bossNames[unitName] then
        return true
    end

    -- Check by classification
    local classification = UnitClassification(unit)
    return classification == "worldboss" or classification == "rareelite" or classification == "elite"
end

core.add = function(unit)
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
        return
    end

    -- If this is a boss unit, manage boss combat state
    if isBoss and distanceValue < 100 then
        local isDead = UnitIsDead(unit)
        if isDead then
            -- Boss died - clear all collected data and exit boss combat
            core.guids = {}
            core.isBossCombat = false
            core.currentBosses[guid] = false

            -- Hide all UI frames
            if RunAway.ui and RunAway.ui.frames then
                for caption, root in pairs(RunAway.ui.frames) do
                    root:Hide()
                end
            end
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
core:RegisterEvent("UPDATE_MOUSEOVER_UNIT")
core:RegisterEvent("PLAYER_TARGET_CHANGED")
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
