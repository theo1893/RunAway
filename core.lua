if RunAway.disabled then
    return
end
local utils = RunAway.utils
local core = CreateFrame("Frame", nil, WorldFrame)

core.guids = {}
core.max_guids = 60

core.add = function(unit)
    local exists, guid = UnitExists(unit)
    if not exists or not guid then
        if core.guids[guid] then
            core.guids[guid] = nil
        end
        return
    end

    local _, distanceValue = utils.GetDistance(unit)

    if core.guids[guid] then
        core.guids[guid] = { time = GetTime(), distance = distanceValue }
        return
    end

    local guids_count = 0
    for _ in pairs(core.guids) do
        guids_count = guids_count + 1
    end

    if guids_count < core.max_guids then
        core.guids[guid] = { time = GetTime(), distance = distanceValue }
        return
    end

    local farthest_guid, farthest_distance = nil, -1

    for guid_entry, data in pairs(core.guids) do
        local entry_distance = type(data) == "table" and data.distance or math.huge

        if entry_distance > farthest_distance then
            farthest_distance = entry_distance
            farthest_guid = guid_entry
        end
    end

    -- Remove farthest unit and add new one
    if farthest_guid then
        core.guids[farthest_guid] = nil
        core.guids[guid] = { time = GetTime(), distance = distanceValue }
    end
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
