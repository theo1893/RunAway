RunAway = {}
RunAway_db = {
  -- Addon enabled state
  enabled = true,

  -- Raid hierarchy: raid -> bosses
  raids = {
    ["卡拉赞之塔"] = {
      order = 1,
      bosses = { "阿诺玛鲁斯" }
    },
    ["祖尔格拉布"] = {
      order = 2,
      bosses = { "老杂斑野猪" }
    },
  },

  -- Boss layouts (referenced by boss name)
  bossLayouts = {
    ["阿诺玛鲁斯"] = {
      name = "阿诺玛鲁斯",
      anchor = "CENTER",
      x = 0,
      y = 0,
      scale = 1.2,
      columns = {
        {
          title = "炸弹",
          enabled = true,
          filter = "aura:arcaneoverload",
          width = 120,
          height = 14,
          spacing = 4,
          maxrow = 20,
          showDistance = true,
          showTimer = false,
          sortBy = nil,  -- "timer", "distance", or nil (no sort)
          sortOrder = "desc",  -- "asc" or "desc"
          alignment = "right",
          colors = {
            bgColor = { 0.3, 0.1, 0.1, 0.9 },
            borderColor = { 1, 0.2, 0.2, 1 },
            titleColor = { 1, 0.4, 0.4, 1 }
          }
        },
        {
          title = "踩圈",
          enabled = true,
          filter = "aura:arcanedampening",
          width = 120,
          height = 14,
          spacing = 4,
          maxrow = 20,
          showDistance = true,
          showTimer = true,
          sortBy = "timer",  -- "timer", "distance", or nil (no sort)
          sortOrder = "desc",  -- "asc" or "desc"
          alignment = "center",
          colors = {
            bgColor = { 0.1, 0.2, 0.1, 0.9 },
            borderColor = { 0.2, 0.8, 0.2, 1 },
            titleColor = { 0.4, 1, 0.4, 1 }
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
          enabled = true,
          filter = "aura:bandage",
          width = 120,
          height = 14,
          spacing = 4,
          maxrow = 20,
          showDistance = true,
          showTimer = true,
          sortBy = "timer",  -- "timer", "distance", or nil (no sort)
          sortOrder = "desc",  -- "asc" or "desc"
          alignment = "center",
          colors = {
            bgColor = { 0.1, 0.2, 0.1, 0.9 },
            borderColor = { 0.2, 0.8, 0.2, 1 },
            titleColor = { 0.4, 1, 0.4, 1 }
          }
        }
      }
    },
  },

  -- Single frame position (shared across all bosses)
  framePosition = nil,

  -- Aura icon and duration mappings
  auras = {
    ["watershield"] = { icon = "Interface\\Icons\\Ability_Shaman_WaterShield", duration = 10 },
    ["bandage"] = { icon = "Interface\\Icons\\INV_Misc_Bandage_08", duration = 60 },
    ["arcaneoverload"] = { icon = "Interface\\Icons\\INV_Misc_Bomb_04", duration = 15 },
    ["arcanedampening"] = { icon = "Interface\\Icons\\Spell_Nature_AbolishMagic", duration = 45 },
  },
}

-- Shared UI templates
RunAway.templates = {
  border = {
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    tile = true, tileSize = 16, edgeSize = 8,
    insets = { left = 2, right = 2, top = 2, bottom = 2 }
  },
  background = {
    bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
    tile = true, tileSize = 16, edgeSize = 8,
    insets = { left = 0, right = 0, top = 0, bottom = 0 }
  }
}

if not GetPlayerBuffID or not CombatLogAdd or not SpellInfo then
  local notify = CreateFrame("Frame", nil, UIParent)
  notify:SetScript("OnUpdate", function()
    DEFAULT_CHAT_FRAME:AddMessage("|cffffcc00Run|cffffffffAway:|cffffaaaa Couldn't detect SuperWoW.")
    this:Hide()
  end)

  RunAway.disabled = true
end