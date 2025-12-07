if RunAway.disabled then
    return
end

local utils = {}

-- ============================================================================
-- Arcane Overload tracking for Arcane Dampening validation
-- Players must have Arcane Overload before Arcane Dampening is recognized
-- ============================================================================
utils.arcaneOverloadHistory = {}
utils.arcaneDampeningActive = {}  -- Track players currently showing arcanedampening

-- Reset Arcane Overload tracking (called when boss combat ends)
utils.ResetArcaneOverloadHistory = function()
    utils.arcaneOverloadHistory = {}
    utils.arcaneDampeningActive = {}
end

-- ============================================================================
-- Performance: Cache global functions locally
-- This avoids global table lookups on every function call (significant in OnUpdate)
-- ============================================================================
local pairs = pairs
local type = type
local tonumber = tonumber
local unpack = unpack
local floor = math.floor
local min = math.min
local max = math.max
local huge = math.huge
local format = string.format
local gsub = string.gsub

-- Cache WoW API functions
local UnitExists = UnitExists
local UnitIsPlayer = UnitIsPlayer
local UnitClass = UnitClass
local UnitLevel = UnitLevel
local UnitClassification = UnitClassification
local UnitReaction = UnitReaction
local UnitDebuff = UnitDebuff
local CheckInteractDistance = CheckInteractDistance
local GetDifficultyColor = GetDifficultyColor

-- ============================================================================
-- String split utility (optimized)
-- ============================================================================
utils.strsplit = function(delimiter, subject)
    if not subject then
        return nil
    end
    local delim = delimiter or ":"
    local fields = {}
    local n = 0
    local pattern = "([^" .. delim .. "]+)"
    gsub(subject, pattern, function(c)
        n = n + 1
        fields[n] = c
    end)
    return unpack(fields)
end

-- ============================================================================
-- RGB to hex color string (optimized)
-- ============================================================================
local _r, _g, _b, _a
utils.rgbhex = function(r, g, b, a)
    local t = type(r)
    if t == "table" then
        if r.r then
            _r, _g, _b, _a = r.r, r.g, r.b, r.a or 1
        elseif r[3] then
            _r, _g, _b, _a = r[1], r[2], r[3], r[4] or 1
        else
            return ""
        end
    elseif t == "number" then
        _r, _g, _b, _a = r, g, b, a or 1
    else
        return ""
    end

    -- Clamp values to 0-1 range
    if _r > 1 then _r = 1 end
    if _g > 1 then _g = 1 end
    if _b > 1 then _b = 1 end
    if _a > 1 then _a = 1 end

    return format("|c%02x%02x%02x%02x", _a * 255, _r * 255, _g * 255, _b * 255)
end

-- ============================================================================
-- Unit color functions (optimized with local caching)
-- ============================================================================
utils.GetReactionColor = function(unitstr)
    local reaction = UnitReaction(unitstr, "player")
    local color = reaction and UnitReactionColor[reaction]
    local r, g, b = 0.8, 0.8, 0.8

    if color then
        r, g, b = color.r, color.g, color.b
    end

    return utils.rgbhex(r, g, b), r, g, b
end

utils.GetUnitColor = function(unitstr)
    if UnitIsPlayer(unitstr) then
        local _, class = UnitClass(unitstr)
        local classColor = class and RAID_CLASS_COLORS[class]

        if classColor then
            return utils.rgbhex(classColor.r, classColor.g, classColor.b), classColor.r, classColor.g, classColor.b
        end
        return utils.rgbhex(0.8, 0.8, 0.8), 0.8, 0.8, 0.8
    end

    return utils.GetReactionColor(unitstr)
end

utils.GetLevelColor = function(unitstr)
    local level = UnitLevel(unitstr)
    local color = GetDifficultyColor(level)
    local r, g, b = 0.8, 0.8, 0.8

    if color then
        r, g, b = color.r, color.g, color.b
    end

    return utils.rgbhex(r, g, b), r, g, b
end

-- ============================================================================
-- Level string with elite classification (optimized)
-- ============================================================================
-- Pre-defined suffix lookup table (avoids string comparisons in hot path)
local eliteSuffix = {
    worldboss = "B",
    rareelite = "R+",
    elite = "+",
    rare = "R"
}

utils.GetLevelString = function(unitstr)
    local level = UnitLevel(unitstr)
    local levelStr = level == -1 and "??" or level

    local elite = UnitClassification(unitstr)
    local suffix = eliteSuffix[elite]

    if suffix then
        return levelStr .. suffix
    end
    return levelStr
end

-- ============================================================================
-- Distance calculation (optimized)
-- ============================================================================
-- Cache the UnitXP API check (only check once)
local hasUnitXPDistance = nil

-- Pre-defined distance strings (avoids string creation in hot path)
local DIST_INFINITY = "∞"
local DIST_LESS_10 = "<9.9"
local DIST_LESS_11 = "<11"
local DIST_LESS_28 = "≤28"
local DIST_MORE_28 = ">28"

utils.GetDistance = function(unit)
    -- Check UnitXP availability once and cache result
    if hasUnitXPDistance == nil then
        hasUnitXPDistance = pcall(UnitXP, "nop", "nop")
    end

    if hasUnitXPDistance then
        local rawDistance = UnitXP("distanceBetween", "player", unit)
        if not rawDistance then
            return DIST_INFINITY, huge
        end
        return format("%.1f", rawDistance), rawDistance
    end

    -- Fallback: Range check mode (check from closest to farthest)
    if CheckInteractDistance(unit, 3) then
        return DIST_LESS_10, 9.9
    elseif CheckInteractDistance(unit, 2) then
        return DIST_LESS_11, 11
    elseif CheckInteractDistance(unit, 4) or CheckInteractDistance(unit, 1) then
        return DIST_LESS_28, 28
    end

    return DIST_MORE_28, 29
end

-- ============================================================================
-- Aura checking (optimized)
-- ============================================================================
utils.CheckAura = function(unit, auraId)
    if not auraId then
        return false, 0
    end

    local auras = RunAway_db.auras
    if not auras then
        return false, 0
    end

    local auraData = auras[auraId]
    if not auraData then
        return false, 0
    end

    local targetIcon = auraData.icon
    local duration = auraData.duration

    -- Special case: arcaneoverload requires 2 debuffs with the same icon
    if auraId == "arcaneoverload" then
        local i = 1
        local count = 0
        local buffIcon = UnitDebuff(unit, i)
        while buffIcon do
            if buffIcon == targetIcon then
                count = count + 1
                if count >= 2 then
                    -- Record this unit in arcaneOverloadHistory
                    local unitName = UnitName(unit)
                    if unitName then
                        utils.arcaneOverloadHistory[unitName] = true
                    end
                    return true, duration
                end
            end
            i = i + 1
            buffIcon = UnitDebuff(unit, i)
        end
        return false, 0
    end

    -- Special case: arcanedampening requires prior arcaneoverload
    if auraId == "arcanedampening" then
        local unitName = UnitName(unit)
        if not unitName then
            return false, 0
        end

        -- Check if arcanedampening debuff currently exists
        local hasDampening = false
        local i = 1
        local buffIcon = UnitDebuff(unit, i)
        while buffIcon do
            if buffIcon == targetIcon then
                hasDampening = true
                break
            end
            i = i + 1
            buffIcon = UnitDebuff(unit, i)
        end

        -- If player was showing dampening but debuff is now gone, clear history (cycle complete)
        if not hasDampening then
            if utils.arcaneDampeningActive[unitName] then
                utils.arcaneDampeningActive[unitName] = nil
                utils.arcaneOverloadHistory[unitName] = nil
            end
            return false, 0
        end

        -- If player is already showing dampening, keep returning true
        if utils.arcaneDampeningActive[unitName] then
            return true, duration
        end

        -- New dampening detected: validate against arcaneoverload history
        if not utils.arcaneOverloadHistory[unitName] then
            return false, 0
        end

        -- Edge case: player must NOT currently have arcaneoverload (2 stacks)
        local overloadIcon = auras["arcaneoverload"] and auras["arcaneoverload"].icon
        if overloadIcon then
            local j = 1
            local overloadCount = 0
            local oBuffIcon = UnitDebuff(unit, j)
            while oBuffIcon do
                if oBuffIcon == overloadIcon then
                    overloadCount = overloadCount + 1
                    if overloadCount >= 2 then
                        -- Still has arcaneoverload, don't recognize arcanedampening yet
                        return false, 0
                    end
                end
                j = j + 1
                oBuffIcon = UnitDebuff(unit, j)
            end
        end

        -- Validated! Mark as active and return true
        utils.arcaneDampeningActive[unitName] = true
        return true, duration
    end

    -- Check debuffs (iterate with local index)
    local i = 1
    local buffIcon = UnitDebuff(unit, i)
    while buffIcon do
        if buffIcon == targetIcon then
            return true, duration
        end
        i = i + 1
        buffIcon = UnitDebuff(unit, i)
    end

    return false, 0
end

-- ============================================================================
-- Table utilities (optimized)
-- ============================================================================
utils.CountTable = function(tbl)
    if not tbl then
        return 0
    end
    local count = 0
    for _ in pairs(tbl) do
        count = count + 1
    end
    return count
end

RunAway.utils = utils
