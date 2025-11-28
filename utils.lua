if RunAway.disabled then
    return
end

local utils = {}

-- String split utility
utils.strsplit = function(delimiter, subject)
    if not subject then
        return nil
    end
    local delimiter, fields = delimiter or ":", {}
    local pattern = string.format("([^%s]+)", delimiter)
    string.gsub(subject, pattern, function(c)
        fields[table.getn(fields) + 1] = c
    end)
    return unpack(fields)
end

local _r, _g, _b, _a
utils.rgbhex = function(r, g, b, a)
    if type(r) == "table" then
        if r.r then
            _r, _g, _b, _a = r.r, r.g, r.b, (r.a or 1)
        elseif table.getn(r) >= 3 then
            _r, _g, _b, _a = r[1], r[2], r[3], (r[4] or 1)
        end
    elseif tonumber(r) then
        _r, _g, _b, _a = r, g, b, (a or 1)
    end

    if _r and _g and _b and _a then
        -- limit values to 0-1
        _r = _r + 0 > 1 and 1 or _r + 0
        _g = _g + 0 > 1 and 1 or _g + 0
        _b = _b + 0 > 1 and 1 or _b + 0
        _a = _a + 0 > 1 and 1 or _a + 0
        return string.format("|c%02x%02x%02x%02x", _a * 255, _r * 255, _g * 255, _b * 255)
    end

    return ""
end

utils.GetReactionColor = function(unitstr)
    local color = UnitReactionColor[UnitReaction(unitstr, "player")]
    local r, g, b = .8, .8, .8

    if color then
        r, g, b = color.r, color.g, color.b
    end

    return utils.rgbhex(r, g, b), r, g, b
end

utils.GetUnitColor = function(unitstr)
    local r, g, b = .8, .8, .8

    if UnitIsPlayer(unitstr) then
        local _, class = UnitClass(unitstr)

        if RAID_CLASS_COLORS[class] then
            r, g, b = RAID_CLASS_COLORS[class].r, RAID_CLASS_COLORS[class].g, RAID_CLASS_COLORS[class].b
        end
    else
        return utils.GetReactionColor(unitstr)
    end

    return utils.rgbhex(r, g, b), r, g, b
end

utils.GetLevelColor = function(unitstr)
    local color = GetDifficultyColor(UnitLevel(unitstr))
    local r, g, b = .8, .8, .8

    if color then
        r, g, b = color.r, color.g, color.b
    end

    return utils.rgbhex(r, g, b), r, g, b
end

utils.GetLevelString = function(unitstr)
    local level = UnitLevel(unitstr)
    if level == -1 then
        level = "??"
    end

    local elite = UnitClassification(unitstr)
    if elite == "worldboss" then
        level = level .. "B"
    elseif elite == "rareelite" then
        level = level .. "R+"
    elseif elite == "elite" then
        level = level .. "+"
    elseif elite == "rare" then
        level = level .. "R"
    end

    return level
end

-- Cache the UnitXP API check (only check once)
local hasUnitXPDistance = nil

utils.GetDistance = function(unit)
    -- Check UnitXP availability once and cache result
    if hasUnitXPDistance == nil then
        hasUnitXPDistance = pcall(UnitXP, "nop", "nop")
    end

    local distance, distanceValue
    if hasUnitXPDistance then
        local rawDistance = UnitXP("distanceBetween", "player", unit)
        if not rawDistance then
            distance = "∞" -- 无法计算时显示无限远
            distanceValue = math.huge -- 无限大值用于判断
        else
            distance = string.format("%.1f", rawDistance)
            distanceValue = rawDistance -- 保存原始数值用于判断
        end
        -- 范围判断模式
    elseif CheckInteractDistance(unit, 3) then
        -- 9.9码（决斗范围）
        distance = "<9.9"
        distanceValue = 9.9
    elseif CheckInteractDistance(unit, 2) then
        -- 11.11码（交易范围）
        distance = "<11"
        distanceValue = 11
    elseif CheckInteractDistance(unit, 4) or CheckInteractDistance(unit, 1) then
        -- 28码（跟随/查看范围）
        distance = "≤28"
        distanceValue = 28
    else
        distance = ">28"
        distanceValue = 29 -- 用29代表超出28码的起始值
    end

    return distance, distanceValue
end

-- Check if unit has a specific aura, returns (exists, duration)
utils.CheckAura = function(unit, auraId)
    if not auraId then
        return false, 0
    end

    local auraData = RunAway_db.auras and RunAway_db.auras[auraId]
    if not auraData then
        return false, 0
    end

    local targetIcon = auraData.icon

    -- Check debuffs
    local i = 1
    while UnitDebuff(unit, i) do
        local buffIcon = UnitDebuff(unit, i)
        if buffIcon == targetIcon then
            return true, auraData.duration
        end
        i = i + 1
    end

    return false, 0
end

-- Utility function to count table elements (works for both arrays and hash tables)
utils.CountTable = function(tbl)
    local count = 0
    if tbl then
        for _ in pairs(tbl) do
            count = count + 1
        end
    end
    return count
end

RunAway.utils = utils
