if RunAway.disabled then return end

local settings = {}
local templates = RunAway.templates

-- Minimap button configuration
local minimapButtonAngle = 225  -- Default position (degrees)
local minimapButtonRadius = 80

-- Create minimap button
local minimapButton = CreateFrame("Button", "RunAwayMinimapButton", Minimap)
minimapButton:SetWidth(32)
minimapButton:SetHeight(32)
minimapButton:SetFrameStrata("MEDIUM")
minimapButton:SetFrameLevel(8)
minimapButton:EnableMouse(true)
minimapButton:RegisterForClicks("LeftButtonUp", "RightButtonUp")

-- Button textures
minimapButton:SetNormalTexture("Interface\\Icons\\Ability_Rogue_Sprint")
minimapButton.icon = minimapButton:GetNormalTexture()
minimapButton.icon:SetTexCoord(0.05, 0.95, 0.05, 0.95)

-- Border overlay
local border = minimapButton:CreateTexture(nil, "OVERLAY")
border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
border:SetWidth(56)
border:SetHeight(56)
border:SetPoint("TOPLEFT", minimapButton, "TOPLEFT", -8, 8)
minimapButton.border = border

-- Highlight texture
local highlight = minimapButton:CreateTexture(nil, "HIGHLIGHT")
highlight:SetTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")
highlight:SetAllPoints(minimapButton)
minimapButton.highlight = highlight

-- Position the button around minimap
local function UpdateMinimapButtonPosition()
  local angle = math.rad(minimapButtonAngle)
  local x = math.cos(angle) * minimapButtonRadius
  local y = math.sin(angle) * minimapButtonRadius
  minimapButton:SetPoint("CENTER", Minimap, "CENTER", x, y)
end

-- Dragging support for minimap button
minimapButton:RegisterForDrag("LeftButton")
minimapButton:SetScript("OnDragStart", function()
  this.dragging = true
end)

minimapButton:SetScript("OnDragStop", function()
  this.dragging = false
end)

minimapButton:SetScript("OnUpdate", function()
  if not this.dragging then return end

  local mx, my = Minimap:GetCenter()
  local cx, cy = GetCursorPosition()
  local scale = UIParent:GetEffectiveScale()
  cx, cy = cx / scale, cy / scale

  minimapButtonAngle = math.deg(math.atan2(cy - my, cx - mx))
  UpdateMinimapButtonPosition()
end)

-- Tooltip
minimapButton:SetScript("OnEnter", function()
  GameTooltip:SetOwner(this, "ANCHOR_LEFT")
  GameTooltip:AddLine("|cffffcc00RunAway|r")
  GameTooltip:AddLine("|cffffffffLeft-Click:|r Open settings menu", 1, 1, 1)
  GameTooltip:AddLine("|cffffffffDrag:|r Move button", 1, 1, 1)
  if RunAway_db.enabled then
    GameTooltip:AddLine("|cff00ff00Enabled|r", 1, 1, 1)
  else
    GameTooltip:AddLine("|cffff0000Disabled|r", 1, 1, 1)
  end
  GameTooltip:Show()
end)

minimapButton:SetScript("OnLeave", function()
  GameTooltip:Hide()
end)

UpdateMinimapButtonPosition()

-- Dropdown menu system
local dropdownFrames = {}
local currentLevel = 0

-- Create a dropdown frame
local function CreateDropdownFrame(level)
  local frame = CreateFrame("Frame", "RunAwayDropdown" .. level, UIParent)
  frame:SetFrameStrata("DIALOG")
  frame:SetBackdrop(templates.background)
  frame:SetBackdropColor(0.1, 0.1, 0.1, 0.95)

  local border = CreateFrame("Frame", nil, frame)
  border:SetBackdrop(templates.border)
  border:SetBackdropBorderColor(0.6, 0.6, 0.6, 1)
  border:SetPoint("TOPLEFT", frame, "TOPLEFT", -2, 2)
  border:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 2, -2)
  frame.border = border

  frame.buttons = {}
  frame.level = level
  frame:Hide()

  return frame
end

-- Create a menu button
local function CreateMenuButton(parent, index)
  local button = CreateFrame("Button", nil, parent)
  button:SetHeight(20)
  button:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight")
  button:GetHighlightTexture():SetAlpha(0.7)

  local text = button:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  text:SetPoint("LEFT", button, "LEFT", 8, 0)
  text:SetJustifyH("LEFT")
  button.text = text

  -- Arrow for submenus
  local arrow = button:CreateTexture(nil, "OVERLAY")
  arrow:SetTexture("Interface\\ChatFrame\\ChatFrameExpandArrow")
  arrow:SetWidth(16)
  arrow:SetHeight(16)
  arrow:SetPoint("RIGHT", button, "RIGHT", -4, 0)
  arrow:Hide()
  button.arrow = arrow

  -- Checkmark for toggle items
  local check = button:CreateTexture(nil, "OVERLAY")
  check:SetTexture("Interface\\Buttons\\UI-CheckBox-Check")
  check:SetWidth(16)
  check:SetHeight(16)
  check:SetPoint("LEFT", button, "LEFT", 4, 0)
  check:Hide()
  button.check = check

  return button
end

-- Hide all dropdowns at or above a level
local function HideDropdownsAbove(level)
  for i = level, 10 do
    if dropdownFrames[i] then
      dropdownFrames[i]:Hide()
    end
  end
end

-- Hide all dropdowns
local function HideAllDropdowns()
  HideDropdownsAbove(1)
  currentLevel = 0
end

-- Build and show a dropdown menu
local function ShowDropdownMenu(menuData, level, anchorFrame, anchorPoint, relativePoint, xOffset, yOffset)
  -- Create frame if needed
  if not dropdownFrames[level] then
    dropdownFrames[level] = CreateDropdownFrame(level)
  end

  local frame = dropdownFrames[level]

  -- Hide higher level menus
  HideDropdownsAbove(level + 1)

  -- Clear existing buttons
  for _, btn in pairs(frame.buttons) do
    btn:Hide()
  end

  -- Calculate dimensions
  local buttonCount = table.getn(menuData)
  local buttonWidth = 150
  local buttonHeight = 20
  local padding = 4

  frame:SetWidth(buttonWidth + padding * 2)
  frame:SetHeight(buttonCount * buttonHeight + padding * 2)

  -- Create buttons
  for i, item in ipairs(menuData) do
    if not frame.buttons[i] then
      frame.buttons[i] = CreateMenuButton(frame, i)
    end

    local button = frame.buttons[i]
    button:SetWidth(buttonWidth)
    button:SetPoint("TOPLEFT", frame, "TOPLEFT", padding, -padding - (i - 1) * buttonHeight)

    -- Reset button state
    button.text:SetPoint("LEFT", button, "LEFT", 8, 0)
    button.arrow:Hide()
    button.check:Hide()

    -- Set text with color
    if item.disabled then
      button.text:SetTextColor(0.5, 0.5, 0.5)
    elseif item.isTitle then
      button.text:SetTextColor(1, 0.8, 0, 1)
    else
      button.text:SetTextColor(1, 1, 1, 1)
    end
    button.text:SetText(item.text)

    -- Show checkmark for checked items
    if item.checked then
      button.check:Show()
      button.text:SetPoint("LEFT", button, "LEFT", 22, 0)
    end

    -- Show arrow for submenus
    if item.hasSubmenu then
      button.arrow:Show()
    end

    -- Click handler
    button:SetScript("OnClick", function()
      if item.disabled then return end

      if item.func then
        item.func()
        if not item.keepOpen then
          HideAllDropdowns()
        end
      end
    end)

    -- Hover handler for submenus
    button:SetScript("OnEnter", function()
      if item.hasSubmenu and item.submenuFunc then
        local submenuData = item.submenuFunc()
        ShowDropdownMenu(submenuData, level + 1, button, "TOPRIGHT", "TOPLEFT", 0, 0)
      else
        HideDropdownsAbove(level + 1)
      end
    end)

    button:Show()
  end

  -- Position and show frame
  frame:ClearAllPoints()
  if anchorFrame then
    frame:SetPoint(anchorPoint or "TOPLEFT", anchorFrame, relativePoint or "BOTTOMLEFT", xOffset or 0, yOffset or 0)
  else
    frame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
  end

  frame:Show()
  currentLevel = level
end

-- Build aura submenu for a boss
local function BuildAuraSubmenu(bossName)
  local layout = RunAway_db.bossLayouts[bossName]
  if not layout or not layout.columns then
    return {{ text = "No auras configured", disabled = true }}
  end

  local menuData = {}
  for _, column in ipairs(layout.columns) do
    -- Default to enabled if not set
    if column.enabled == nil then
      column.enabled = true
    end

    local displayText = column.title
    if not column.enabled then
      displayText = "|cff888888" .. column.title .. "|r"
    end

    table.insert(menuData, {
      text = displayText,
      checked = column.enabled,
      keepOpen = true,  -- Keep menu open after clicking
      func = function()
        -- Toggle the enabled state
        column.enabled = not column.enabled
        if column.enabled then
          DEFAULT_CHAT_FRAME:AddMessage("|cffffcc00RunAway:|r " .. bossName .. " - " .. column.title .. " |cff00ff00Enabled|r")
        else
          DEFAULT_CHAT_FRAME:AddMessage("|cffffcc00RunAway:|r " .. bossName .. " - " .. column.title .. " |cffff0000Disabled|r")
        end
      end
    })
  end

  return menuData
end

-- Build boss submenu for a raid
local function BuildBossSubmenu(raidName)
  local raid = RunAway_db.raids[raidName]
  if not raid or not raid.bosses then
    return {{ text = "No bosses configured", disabled = true }}
  end

  local menuData = {}
  for _, bossName in ipairs(raid.bosses) do
    table.insert(menuData, {
      text = bossName,
      hasSubmenu = true,
      submenuFunc = function()
        return BuildAuraSubmenu(bossName)
      end
    })
  end

  return menuData
end

-- Build main menu
local function BuildMainMenu()
  local menuData = {}

  -- Enable/Disable toggle
  table.insert(menuData, {
    text = RunAway_db.enabled and "|cff00ff00Enabled|r" or "|cffff0000Disabled|r",
    checked = RunAway_db.enabled,
    func = function()
      RunAway_db.enabled = not RunAway_db.enabled
      if RunAway_db.enabled then
        DEFAULT_CHAT_FRAME:AddMessage("|cffffcc00RunAway:|r |cff00ff00Enabled|r")
      else
        DEFAULT_CHAT_FRAME:AddMessage("|cffffcc00RunAway:|r |cffff0000Disabled|r")
        -- Reset UI when disabled
        if RunAway.core then
          RunAway.core.ResetStatus()
        end
      end
    end
  })

  -- Separator
  table.insert(menuData, {
    text = "──────────",
    disabled = true,
    isTitle = true
  })

  -- Raids
  -- Sort raids by order
  local sortedRaids = {}
  for raidName, raidData in pairs(RunAway_db.raids) do
    table.insert(sortedRaids, { name = raidName, order = raidData.order or 999 })
  end
  table.sort(sortedRaids, function(a, b) return a.order < b.order end)

  for _, raid in ipairs(sortedRaids) do
    table.insert(menuData, {
      text = raid.name,
      hasSubmenu = true,
      submenuFunc = function()
        return BuildBossSubmenu(raid.name)
      end
    })
  end

  return menuData
end

-- Minimap button click handler
minimapButton:SetScript("OnClick", function()
  if arg1 == "LeftButton" then
    if currentLevel > 0 then
      HideAllDropdowns()
    else
      local menuData = BuildMainMenu()
      ShowDropdownMenu(menuData, 1, minimapButton, "TOPLEFT", "BOTTOMLEFT", 0, -4)
    end
  end
end)

-- Close dropdowns when clicking elsewhere
local closeFrame = CreateFrame("Frame", nil, UIParent)
closeFrame:SetAllPoints()
closeFrame:SetFrameStrata("BACKGROUND")
closeFrame:EnableMouse(false)
closeFrame:SetScript("OnUpdate", function()
  if currentLevel > 0 and not MouseIsOver(minimapButton) then
    local mouseOverMenu = false
    for i = 1, currentLevel do
      if dropdownFrames[i] and MouseIsOver(dropdownFrames[i]) then
        mouseOverMenu = true
        break
      end
    end

    if not mouseOverMenu and IsMouseButtonDown("LeftButton") then
      -- Check if click is outside all menus
      local clickedOutside = true
      for i = 1, currentLevel do
        if dropdownFrames[i] and MouseIsOver(dropdownFrames[i]) then
          clickedOutside = false
          break
        end
      end
      if clickedOutside and not MouseIsOver(minimapButton) then
        HideAllDropdowns()
      end
    end
  end
end)

-- Also close on Escape
local escapeFrame = CreateFrame("Frame", "RunAwayEscapeHandler", UIParent)
escapeFrame:EnableKeyboard(true)
escapeFrame:SetPropagateKeyboardInput(true)
escapeFrame:SetScript("OnKeyDown", function()
  if arg1 == "ESCAPE" and currentLevel > 0 then
    HideAllDropdowns()
    this:SetPropagateKeyboardInput(false)
  else
    this:SetPropagateKeyboardInput(true)
  end
end)

RunAway.settings = settings
