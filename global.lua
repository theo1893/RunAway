RunAway = {}
RunAway_db = {
  config = {
    ["Infight NPCs"] = {
      filter = "npc,infight",
      scale = 1, anchor = "CENTER", x = -240, y = 120, width = 100, height = 14, spacing = 4, maxrow = 20
    },

    ["Raid Targets"] = {
      filter = "icon,alive",
      scale = 1, anchor = "CENTER", x = 240, y = 120, width = 100, height = 14, spacing = 4, maxrow = 20
    }
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