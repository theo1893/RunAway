if RunAway.disabled then return end

local settings = {}
local templates = RunAway.templates

-- Minimap button configuration
local minimapButtonAngle = 225  -- Default position (degrees)
local minimapButtonRadius = 80

-- Create minimap button
local minimapButton = CreateFrame("Button", "RunAwayMinimapButton", Minimap)
minimapButton:SetWidth(31)
minimapButton:SetHeight(31)
minimapButton:SetFrameStrata("MEDIUM")
minimapButton:SetFrameLevel(8)
minimapButton:EnableMouse(true)
minimapButton:RegisterForClicks("LeftButtonUp", "RightButtonUp")
minimapButton:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")

-- Icon texture (centered and properly sized for circular mask)
local icon = minimapButton:CreateTexture(nil, "BACKGROUND")
icon:SetTexture("Interface\\Icons\\Ability_Rogue_Sprint")
icon:SetWidth(20)
icon:SetHeight(20)
icon:SetPoint("CENTER", minimapButton, "CENTER", 0, 0)
icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
minimapButton.icon = icon

-- Border overlay (standard minimap tracking button style)
local border = minimapButton:CreateTexture(nil, "OVERLAY")
border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
border:SetWidth(54)
border:SetHeight(54)
border:SetPoint("TOPLEFT", minimapButton, "TOPLEFT", -2, 2)
minimapButton.border = border

-- Pushed texture effect
minimapButton:SetScript("OnMouseDown", function()
  if arg1 == "LeftButton" and not this.dragging then
    this.icon:ClearAllPoints()
    this.icon:SetPoint("CENTER", this, "CENTER", 1, -1)
  end
end)

minimapButton:SetScript("OnMouseUp", function()
  this.icon:ClearAllPoints()
  this.icon:SetPoint("CENTER", this, "CENTER", 0, 0)
end)

-- Position the button around minimap
local function UpdateMinimapButtonPosition()
  local angle = math.rad(minimapButtonAngle)
  local x = math.cos(angle) * minimapButtonRadius
  local y = math.sin(angle) * minimapButtonRadius
  minimapButton:ClearAllPoints()
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
  GameTooltip:AddLine("|cffffcc00快|cffffffff跑！")
  GameTooltip:AddLine("|cffffffff左键:|r 打开设置菜单", 1, 1, 1)
  GameTooltip:AddLine("|cffffffff拖拽:|r 移动按钮", 1, 1, 1)
  if RunAway_db.enabled then
    GameTooltip:AddLine("|cff00ff00已启用|r", 1, 1, 1)
  else
    GameTooltip:AddLine("|cffff0000已禁用|r", 1, 1, 1)
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

-- Prettier dropdown backdrop
local dropdownBackdrop = {
  bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
  edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
  tile = true,
  tileSize = 16,
  edgeSize = 16,
  insets = { left = 4, right = 4, top = 4, bottom = 4 }
}

-- Create a dropdown frame
local function CreateDropdownFrame(level)
  local frame = CreateFrame("Frame", "RunAwayDropdown" .. level, UIParent)
  frame:SetFrameStrata("DIALOG")
  frame:SetFrameLevel(100 + level)
  frame:SetBackdrop(dropdownBackdrop)
  frame:SetBackdropColor(0.05, 0.05, 0.1, 0.95)
  frame:SetBackdropBorderColor(0.4, 0.4, 0.5, 1)

  -- Title bar for all menu levels
  local title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  title:SetPoint("TOP", frame, "TOP", 0, -8)
  title:SetText("|cffffcc00快|cffffffff跑！")
  frame.title = title

  frame.buttons = {}
  frame.level = level
  frame:Hide()

  return frame
end

-- Create a menu button
local function CreateMenuButton(parent, index)
  local button = CreateFrame("Button", nil, parent)
  button:SetHeight(18)

  -- Highlight texture
  local highlight = button:CreateTexture(nil, "HIGHLIGHT")
  highlight:SetTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight")
  highlight:SetBlendMode("ADD")
  highlight:SetAllPoints(button)
  highlight:SetAlpha(0.5)

  -- Text
  local text = button:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  text:SetPoint("LEFT", button, "LEFT", 10, 0)
  text:SetJustifyH("LEFT")
  button.text = text

  -- Arrow for submenus
  local arrow = button:CreateTexture(nil, "OVERLAY")
  arrow:SetTexture("Interface\\ChatFrame\\ChatFrameExpandArrow")
  arrow:SetWidth(14)
  arrow:SetHeight(14)
  arrow:SetPoint("RIGHT", button, "RIGHT", -4, 0)
  arrow:Hide()
  button.arrow = arrow

  -- Checkmark for toggle items
  local check = button:CreateTexture(nil, "OVERLAY")
  check:SetTexture("Interface\\Buttons\\UI-CheckBox-Check")
  check:SetWidth(14)
  check:SetHeight(14)
  check:SetPoint("LEFT", button, "LEFT", 2, 0)
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
local function ShowDropdownMenu(menuData, level, anchorFrame, menuTitle)
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

  -- Set title
  if frame.title then
    if menuTitle then
      frame.title:SetText("|cffffcc00" .. menuTitle .. "|r")
    else
      frame.title:SetText("|cffffcc00快|cffffffff跑！")
    end
  end

  -- Calculate dimensions
  local buttonCount = table.getn(menuData)
  local buttonWidth = 160
  local buttonHeight = 18
  local padding = 8
  local titleHeight = 20  -- Always have title space

  frame:SetWidth(buttonWidth + padding * 2)
  frame:SetHeight(buttonCount * buttonHeight + padding * 2 + titleHeight)

  -- Create buttons
  for i, item in ipairs(menuData) do
    if not frame.buttons[i] then
      frame.buttons[i] = CreateMenuButton(frame, i)
    end

    local button = frame.buttons[i]
    button:SetWidth(buttonWidth)
    button:SetPoint("TOPLEFT", frame, "TOPLEFT", padding, -padding - titleHeight - (i - 1) * buttonHeight)

    -- Store item data on button for closure access in Lua 5.0
    button.itemData = item
    button.menuLevel = level

    -- Reset button state
    button.text:SetPoint("LEFT", button, "LEFT", 10, 0)
    button.arrow:Hide()
    button.check:Hide()

    -- Set text with color
    if item.disabled then
      button.text:SetTextColor(0.5, 0.5, 0.5)
    elseif item.isTitle then
      button.text:SetTextColor(0.7, 0.7, 0.7, 1)
    else
      button.text:SetTextColor(1, 1, 1, 1)
    end
    button.text:SetText(item.text)

    -- Show checkmark for checked items
    if item.checked then
      button.check:Show()
      button.text:SetPoint("LEFT", button, "LEFT", 20, 0)
    end

    -- Show arrow for submenus
    if item.hasSubmenu then
      button.arrow:Show()
    end

    -- Click handler
    button:SetScript("OnClick", function()
      local data = this.itemData
      if not data or data.disabled then return end

      if data.func then
        data.func()
        if not data.keepOpen then
          HideAllDropdowns()
        end
      end
    end)

    -- Hover handler for submenus
    button:SetScript("OnEnter", function()
      local data = this.itemData
      local lvl = this.menuLevel
      if data and data.hasSubmenu and data.submenuFunc then
        local submenuData = data.submenuFunc()
        -- Pass menuArg as the title for submenus
        ShowDropdownMenu(submenuData, lvl + 1, this, data.menuArg)
        -- Store menu info for refresh after frame is created
        if dropdownFrames[lvl + 1] and data.menuArg then
          dropdownFrames[lvl + 1].menuArg = data.menuArg
        end
      else
        HideDropdownsAbove(lvl + 1)
      end
    end)

    button:Show()
  end

  -- Position and show frame
  frame:ClearAllPoints()
  if anchorFrame then
    local anchorX, anchorY = anchorFrame:GetCenter()
    local screenWidth = GetScreenWidth()
    local screenHeight = GetScreenHeight()
    local scale = UIParent:GetEffectiveScale()
    local frameWidth = frame:GetWidth()
    local frameHeight = frame:GetHeight()

    -- For level 1 (main menu from minimap button)
    if level == 1 then
      -- Determine best horizontal position based on minimap location
      if anchorX > screenWidth / 2 then
        -- Button is on right side, open menu to the left
        frame:SetPoint("TOPRIGHT", anchorFrame, "LEFT", 0, 10)
      else
        -- Button is on left side, open menu to the right
        frame:SetPoint("TOPLEFT", anchorFrame, "RIGHT", 0, 10)
      end
    else
      -- For submenus, always open to the left
      -- Offset to align first submenu button with parent button (title + padding)
      local titleOffset = 28
      frame:SetPoint("TOPRIGHT", anchorFrame, "TOPLEFT", -2, titleOffset)
    end
  else
    frame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
  end

  frame:Show()
  currentLevel = level
end

-- Check if a boss has any enabled auras
local function IsBossEnabled(bossName)
  local layout = RunAway_db.bossLayouts and RunAway_db.bossLayouts[bossName]
  if not layout or not layout.columns then return false end
  for _, column in ipairs(layout.columns) do
    if column.enabled ~= false then
      return true
    end
  end
  return false
end

-- Check if a raid has any enabled bosses
local function IsRaidEnabled(raidName)
  local raid = RunAway_db.raids and RunAway_db.raids[raidName]
  if not raid or not raid.bosses then return false end
  for _, bossName in ipairs(raid.bosses) do
    if IsBossEnabled(bossName) then
      return true
    end
  end
  return false
end

-- Forward declarations for refresh
local BuildMainMenu, BuildBossSubmenu, BuildAuraSubmenu

-- Refresh all open dropdown menus
local function RefreshDropdowns()
  if currentLevel < 1 then return end

  -- Store current menu anchors before rebuilding
  local anchors = {}
  for i = 1, currentLevel do
    if dropdownFrames[i] and dropdownFrames[i]:IsShown() then
      anchors[i] = {
        frame = dropdownFrames[i],
        menuArg = dropdownFrames[i].menuArg
      }
    end
  end

  -- Rebuild level 1 (main menu)
  if anchors[1] then
    local menuData = BuildMainMenu()
    ShowDropdownMenu(menuData, 1, minimapButton)
  end

  -- Rebuild level 2 (boss submenu) if open
  if anchors[2] and anchors[2].menuArg then
    local menuData = BuildBossSubmenu(anchors[2].menuArg)
    local parentBtn = nil
    -- Find the parent button in level 1 by menuArg
    if dropdownFrames[1] then
      for _, btn in pairs(dropdownFrames[1].buttons) do
        if btn.itemData and btn.itemData.menuArg == anchors[2].menuArg then
          parentBtn = btn
          break
        end
      end
    end
    if parentBtn then
      ShowDropdownMenu(menuData, 2, parentBtn, anchors[2].menuArg)
      dropdownFrames[2].menuArg = anchors[2].menuArg
    end
  end

  -- Rebuild level 3 (aura submenu) if open
  if anchors[3] and anchors[3].menuArg then
    local menuData = BuildAuraSubmenu(anchors[3].menuArg)
    local parentBtn = nil
    -- Find the parent button in level 2 by menuArg
    if dropdownFrames[2] then
      for _, btn in pairs(dropdownFrames[2].buttons) do
        if btn.itemData and btn.itemData.menuArg == anchors[3].menuArg then
          parentBtn = btn
          break
        end
      end
    end
    if parentBtn then
      ShowDropdownMenu(menuData, 3, parentBtn, anchors[3].menuArg)
      dropdownFrames[3].menuArg = anchors[3].menuArg
    end
  end
end

-- Build aura submenu for a boss
BuildAuraSubmenu = function(bossName)
  local layout = RunAway_db.bossLayouts[bossName]
  if not layout or not layout.columns then
    return {{ text = "No auras configured", disabled = true }}
  end

  local menuData = {}
  for i, col in ipairs(layout.columns) do
    local column = col  -- Capture for Lua 5.0 closure
    local columnTitle = column.title

    -- Default to enabled if not set
    if column.enabled == nil then
      column.enabled = true
    end

    local displayText = columnTitle
    if not column.enabled then
      displayText = "|cff888888" .. columnTitle .. "|r"
    end

    table.insert(menuData, {
      text = displayText,
      checked = column.enabled,
      keepOpen = true,  -- Keep menu open after clicking
      func = function()
        -- Toggle the enabled state
        column.enabled = not column.enabled
        if column.enabled then
          DEFAULT_CHAT_FRAME:AddMessage("|cffffcc00快跑！|r " .. bossName .. " - " .. columnTitle .. " |cff00ff00已启用|r")
        else
          DEFAULT_CHAT_FRAME:AddMessage("|cffffcc00快跑！|r " .. bossName .. " - " .. columnTitle .. " |cffff0000已禁用|r")
        end
        -- Refresh all menus to update enabled status
        RefreshDropdowns()
      end
    })
  end

  return menuData
end

-- Build boss submenu for a raid
BuildBossSubmenu = function(raidName)
  local raid = RunAway_db.raids[raidName]
  if not raid or not raid.bosses then
    return {{ text = "No bosses configured", disabled = true }}
  end

  local menuData = {}
  for _, boss in ipairs(raid.bosses) do
    local bossName = boss  -- Capture for Lua 5.0 closure
    local bossEnabled = IsBossEnabled(bossName)
    local displayText = bossName
    if not bossEnabled then
      displayText = "|cff888888" .. bossName .. "|r"
    else
      displayText = "|cff00ff00" .. bossName .. "|r"
    end
    table.insert(menuData, {
      text = displayText,
      menuArg = bossName,  -- Raw name for refresh
      hasSubmenu = true,
      submenuFunc = function()
        return BuildAuraSubmenu(bossName)
      end
    })
  end

  return menuData
end

-- Build main menu
BuildMainMenu = function()
  local menuData = {}

  -- Enable/Disable toggle
  local enableText = RunAway_db.enabled and "启用" or "|cff888888启用|r"
  table.insert(menuData, {
    text = enableText,
    checked = RunAway_db.enabled,
    keepOpen = true,
    func = function()
      RunAway_db.enabled = not RunAway_db.enabled
      if not RunAway_db.enabled then
        -- Reset UI when disabled
        if RunAway.core then
          RunAway.core.ResetStatus()
        end
      end
      RefreshDropdowns()
    end
  })

  -- Debug toggle
  local debugText = RunAway_db.debug and "调试" or "|cff888888调试|r"
  table.insert(menuData, {
    text = debugText,
    checked = RunAway_db.debug,
    keepOpen = true,
    func = function()
      RunAway_db.debug = not RunAway_db.debug
      if RunAway_db.debug then
        DEFAULT_CHAT_FRAME:AddMessage("|cffffcc00快跑！|r 调试模式 |cff00ff00开启|r")
      else
        DEFAULT_CHAT_FRAME:AddMessage("|cffffcc00快跑！|r 调试模式 |cffff0000关闭|r")
      end
      RefreshDropdowns()
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
  if RunAway_db.raids then
    for raidName, raidData in pairs(RunAway_db.raids) do
      table.insert(sortedRaids, { name = raidName, order = raidData.order or 999 })
    end
    table.sort(sortedRaids, function(a, b) return a.order < b.order end)

    for _, raid in ipairs(sortedRaids) do
      local raidName = raid.name  -- Capture for Lua 5.0 closure
      local raidEnabled = IsRaidEnabled(raidName)
      local displayText = raidName
      if not raidEnabled then
        displayText = "|cff888888" .. raidName .. "|r"
      else
        displayText = "|cff00ff00" .. raidName .. "|r"
      end
      table.insert(menuData, {
        text = displayText,
        menuArg = raidName,  -- Raw name for refresh
        hasSubmenu = true,
        submenuFunc = function()
          return BuildBossSubmenu(raidName)
        end
      })
    end
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
      ShowDropdownMenu(menuData, 1, minimapButton)
    end
  end
end)

-- Close dropdowns when clicking elsewhere
local closeFrame = CreateFrame("Button", "RunAwayCloseFrame", UIParent)
closeFrame:SetAllPoints()
closeFrame:SetFrameStrata("DIALOG")
closeFrame:SetFrameLevel(1)
closeFrame:Hide()
closeFrame:RegisterForClicks("LeftButtonUp", "RightButtonUp")
closeFrame:SetScript("OnClick", function()
  HideAllDropdowns()
end)

-- Show/hide the close frame when dropdowns open/close
local origHideAllDropdowns = HideAllDropdowns
HideAllDropdowns = function()
  origHideAllDropdowns()
  closeFrame:Hide()
end

local origShowDropdownMenu = ShowDropdownMenu
ShowDropdownMenu = function(menuData, level, anchorFrame, menuTitle)
  closeFrame:Show()
  origShowDropdownMenu(menuData, level, anchorFrame, menuTitle)
end

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
