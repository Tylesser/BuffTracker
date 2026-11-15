local _, ns = ...

-- Options page: Esc > Options > AddOns > Tylesser - Buff Tracker
-- Left: the tracked buffs. Right: buffs on the character and spells from the spellbook to add.

local ROW_HEIGHT = 26
local TRACKED_ROW_HEIGHT = 50 -- two lines: name and "when" on top, item and alert below
local LEFT_WIDTH = 270
local RIGHT_X = 330
local RIGHT_WIDTH = 240

local panel, lockCheck, clickCheck, shapeButton, sizeText, searchBox, searchHint, status, presetButton
local trackedList, pickerList
local spellbook = {}

local function SetIcon(texture, icon)
  texture:SetTexture(icon or ns.DEFAULT_ICON)
  texture:SetTexCoord(0.08, 0.92, 0.08, 0.92)
end

local function CreateList(x, y, width, rowHeight)
  local scroll = CreateFrame("ScrollFrame", nil, panel, "UIPanelScrollFrameTemplate")
  scroll:SetPoint("TOPLEFT", panel, "TOPLEFT", x, y)
  scroll:SetPoint("BOTTOMLEFT", panel, "BOTTOMLEFT", x, 20)
  scroll:SetWidth(width)
  local content = CreateFrame("Frame", nil, scroll)
  content:SetSize(width, ROW_HEIGHT)
  scroll:SetScrollChild(content)
  local empty = content:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
  empty:SetPoint("TOPLEFT", 4, -6)
  empty:SetWidth(width - 8)
  empty:SetJustifyH("LEFT")
  return { scroll = scroll, content = content, empty = empty, rows = {}, width = width, rowHeight = rowHeight }
end

local function Finish(list, used, emptyText)
  for index = used + 1, #list.rows do
    list.rows[index]:Hide()
  end
  list.empty:SetText(used == 0 and emptyText or "")
  list.content:SetHeight(math.max(used * list.rowHeight, list.rowHeight))
end

local function ModeTooltip(self)
  GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
  GameTooltip:AddLine("When to show this buff")
  GameTooltip:AddLine("When missing: only while it's not on you.", 1, 1, 1)
  GameTooltip:AddLine("When active: only while it's on you.", 1, 1, 1)
  GameTooltip:AddLine("Always: dimmed with a red border while it's missing.", 1, 1, 1)
  GameTooltip:AddLine("Click to change.", 0.6, 0.6, 0.6)
  GameTooltip:Show()
end

local function Hide()
  GameTooltip:Hide()
end

local function ItemTooltip(self)
  local entry = self:GetParent().entry
  GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
  GameTooltip:AddLine("Item to use")
  GameTooltip:AddLine("Clicking the icon uses this item, like a food for Well Fed or an elixir.", 1, 1, 1, true)
  if entry.slot then
    GameTooltip:AddLine("For a weapon enchant: an oil, poison or sharpening stone, put on this weapon.", 1, 1, 1, true)
  else
    GameTooltip:AddLine("Without one, a bag item named after the buff is used when you don't know its spell.",
      1, 1, 1, true)
  end
  GameTooltip:AddLine("Click: next usable item in your bags. Right-click: none.", 0.6, 0.6, 0.6, true)
  GameTooltip:AddLine("Or type /btrack item " .. entry.name .. " = <item name>", 0.6, 0.6, 0.6, true)
  GameTooltip:Show()
end

local function AlertTooltip(self)
  GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
  GameTooltip:AddLine("Alert")
  GameTooltip:AddLine("Play a sound and flash the icon when this buff drops during combat.", 1, 1, 1, true)
  GameTooltip:AddLine("Only works while the game lets addons see your buffs in combat.", 0.6, 0.6, 0.6, true)
  GameTooltip:Show()
end

-- "Use: Roasted Quail (4)", "Use: Elixir of the Mongoose (auto)", or "Use item: none".
local function ItemLabel(entry)
  local id, auto = ns.ItemFor(entry)
  if not id then
    return "Use item: none"
  end
  local name = ns.ItemName(id) or ("item " .. id)
  if auto then
    return "Use: " .. name .. " (auto)"
  end
  return string.format("Use: %s (%d)", name, ns.ItemCount(id))
end

local function GetTrackedRow(index)
  local row = trackedList.rows[index]
  if row then
    return row
  end
  local height = trackedList.rowHeight
  row = CreateFrame("Frame", nil, trackedList.content)
  row:SetSize(trackedList.width, height)
  row:SetPoint("TOPLEFT", 0, -(index - 1) * height)

  row.icon = row:CreateTexture(nil, "ARTWORK")
  row.icon:SetSize(22, 22)
  row.icon:SetPoint("TOPLEFT", 2, -2)

  row.remove = ns.T.Button(row, 22, 22, "X")
  row.remove:SetPoint("TOPRIGHT", 0, -2)
  row.remove:SetScript("OnClick", function(self)
    ns.RemoveBuff(self:GetParent().entry.name)
  end)

  row.mode = ns.T.Button(row, 96, 22)
  row.mode:SetPoint("RIGHT", row.remove, "LEFT", -2, 0)
  row.mode:SetScript("OnClick", function(self)
    ns.CycleMode(self:GetParent().entry)
  end)
  row.mode:SetScript("OnEnter", ModeTooltip)
  row.mode:SetScript("OnLeave", Hide)

  row.name = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  row.name:SetPoint("LEFT", row.icon, "RIGHT", 6, 0)
  row.name:SetPoint("RIGHT", row.mode, "LEFT", -4, 0)
  row.name:SetJustifyH("LEFT")
  row.name:SetWordWrap(false)

  -- second line: the item a click uses, and the combat alert
  row.item = ns.T.Button(row, 170, 20)
  row.item:SetPoint("TOPLEFT", 28, -26)
  row.item:RegisterForClicks("LeftButtonUp", "RightButtonUp")
  row.item:SetScript("OnClick", function(self, button)
    local entry = self:GetParent().entry
    if button == "RightButton" then
      ns.SetItem(entry, nil)
    else
      ns.CycleItem(entry)
    end
  end)
  row.item:SetScript("OnEnter", ItemTooltip)
  row.item:SetScript("OnLeave", Hide)

  row.alert = ns.T.Check(row, "Alert", "GameFontHighlightSmall")
  row.alert:SetPoint("LEFT", row.item, "RIGHT", 4, 0)
  row.alert:SetHitRectInsets(0, -(row.alert.Text:GetStringWidth() + 4), 0, 0)
  row.alert:SetScript("OnClick", function(self)
    self:GetParent().entry.alert = self:GetChecked() and true or nil
  end)
  row.alert:SetScript("OnEnter", AlertTooltip)
  row.alert:SetScript("OnLeave", Hide)

  trackedList.rows[index] = row
  return row
end

local function GetPickerRow(index)
  local row = pickerList.rows[index]
  if row then
    return row
  end
  row = CreateFrame("Button", nil, pickerList.content)
  row:SetSize(pickerList.width, ROW_HEIGHT)
  row:SetPoint("TOPLEFT", 0, -(index - 1) * ROW_HEIGHT)
  row:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight", "ADD")

  row.icon = row:CreateTexture(nil, "ARTWORK")
  row.icon:SetSize(22, 22)
  row.icon:SetPoint("LEFT", 2, 0)

  row.tag = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  row.tag:SetPoint("RIGHT", -4, 0)
  row.tag:SetTextColor(0.25, 1, 0.25)

  row.name = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  row.name:SetPoint("LEFT", row.icon, "RIGHT", 6, 0)
  row.name:SetPoint("RIGHT", row.tag, "LEFT", -4, 0)
  row.name:SetJustifyH("LEFT")
  row.name:SetWordWrap(false)

  row:SetScript("OnClick", function(self)
    if self.weaponSlot then
      ns.AddWeapon(self.weaponSlot)
    else
      ns.AddBuff(self.spellName, self.spellIcon)
    end
  end)

  pickerList.rows[index] = row
  return row
end

local function RefreshTracked()
  local used = 0
  for index, entry in ipairs(ns.db.tracked) do
    local row = GetTrackedRow(index)
    row.entry = entry
    SetIcon(row.icon, ns.EntryIcon(entry))
    row.name:SetText(entry.name)
    row.mode:SetText(ns.MODE_LABELS[entry.mode])
    row.item:SetText(ItemLabel(entry))
    row.alert:SetChecked(entry.alert or false)
    row:Show()
    used = index
  end
  Finish(trackedList, used, "Nothing tracked yet. Pick a buff from the list on the right.")
end

local function RefreshPicker()
  local filter = strtrim(searchBox:GetText()):lower()
  local used = 0
  local seen = {}

  local function Add(name, icon, tag, weaponSlot)
    local key = name:lower()
    if seen[key] or ns.IsTracked(name) then
      return
    end
    seen[key] = true
    if filter ~= "" and not key:find(filter, 1, true) then
      return
    end
    used = used + 1
    local row = GetPickerRow(used)
    row.spellName, row.spellIcon, row.weaponSlot = name, icon, weaponSlot
    SetIcon(row.icon, icon)
    row.name:SetText(name)
    row.tag:SetText(tag)
    row:Show()
  end

  for _, buff in ipairs(ns.buffs) do
    Add(buff.name, buff.icon, "on you")
  end
  for _, spell in ipairs(spellbook) do
    Add(spell.name, spell.icon, "")
  end
  for _, slot in ipairs(ns.WEAPON_SLOTS) do
    Add(ns.WEAPON_NAMES[slot], GetInventoryItemTexture and GetInventoryItemTexture("player", slot), "weapon", slot)
  end
  Finish(pickerList, used, "No matches. Press Enter to track this name anyway. It must match the buff's name exactly.")

  searchHint:SetShown(searchBox:GetText() == "" and not searchBox:HasFocus())
  if ns.scanComplete then
    status:SetText("")
  else
    status:SetText("The game is hiding your buffs right now. They'll update when it stops.")
  end
end

function ns.RefreshOptions()
  if not (panel and panel:IsVisible()) then
    return
  end
  lockCheck:SetChecked(ns.db.locked)
  clickCheck:SetChecked(ns.db.clickToCast)
  sizeText:SetText("Icon size: " .. ns.db.iconSize)
  shapeButton:SetText("Shape: " .. (ns.SHAPE_LABELS[ns.db.iconShape] or "Square"))
  local preset = ns.PresetBuffs()
  presetButton:SetText("Add " .. (UnitClass("player") or "class") .. " basics")
  presetButton:SetShown(preset ~= nil)
  presetButton:SetEnabled(preset ~= nil and #preset > 0)
  RefreshTracked()
  RefreshPicker()
end

local function PresetTooltip(self)
  local list = ns.PresetBuffs() or {}
  GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
  GameTooltip:AddLine(self:GetText())
  if #list > 0 then
    GameTooltip:AddLine("Adds: " .. table.concat(list, ", "), 1, 1, 1, true)
  else
    GameTooltip:AddLine("You already track the basic buffs of your class that you know.", 1, 1, 1, true)
  end
  GameTooltip:Show()
end

local function AddFromSearchBox()
  local entry, reason = ns.AddBuff(searchBox:GetText())
  if entry then
    searchBox:SetText("")
    searchBox:ClearFocus()
  else
    print(ns.PREFIX .. reason)
  end
end

local function CreateSizeButton(label, delta)
  local button = ns.T.Button(panel, 24, 22, label)
  button:SetScript("OnClick", function()
    ns.SetIconSize(ns.db.iconSize + delta)
  end)
  return button
end

function ns.CreateOptions()
  panel = CreateFrame("Frame")
  panel.name = ns.TITLE

  local top = ns.T.OPTIONS_TOP
  local subtitle = ns.T.OptionsPage(panel, "Buff Tracker",
    "Choose the buffs to watch. The list is saved per character.")

  lockCheck = ns.T.Check(panel, "Lock position (untick to drag the icons)")
  lockCheck:SetPoint("TOPLEFT", panel, "TOPLEFT", 14, top)
  lockCheck:SetScript("OnClick", function(self)
    ns.SetLocked(self:GetChecked() and true or false)
  end)

  clickCheck = ns.T.Check(panel, "Click icons to cast (out of combat)")
  clickCheck:SetPoint("TOPLEFT", lockCheck, "BOTTOMLEFT", 0, 2)
  -- only the label is clickable: the Shape button sits to the right
  clickCheck:SetHitRectInsets(0, -(clickCheck.Text:GetStringWidth() + 4), 0, 0)
  clickCheck:SetScript("OnClick", function(self)
    ns.SetClickToCast(self:GetChecked() and true or false)
  end)

  local smaller = CreateSizeButton("-", -2)
  smaller:SetPoint("TOPLEFT", panel, "TOPLEFT", RIGHT_X, top)
  sizeText = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
  sizeText:SetPoint("LEFT", smaller, "RIGHT", 6, 0)
  sizeText:SetWidth(100)
  local larger = CreateSizeButton("+", 2)
  larger:SetPoint("LEFT", sizeText, "RIGHT", 6, 0)

  -- Square or circle, for the icon row and the party buttons.
  shapeButton = ns.T.Button(panel, 24 + 6 + 100 + 6 + 24, 22)
  shapeButton:SetPoint("TOPLEFT", smaller, "BOTTOMLEFT", 0, -4)
  shapeButton:SetScript("OnClick", function()
    ns.CycleShape()
  end)

  local trackedTitle = ns.T.Heading(panel, "Tracked buffs", LEFT_WIDTH)
  trackedTitle:SetPoint("TOPLEFT", panel, "TOPLEFT", 16, top - 60)

  -- "Add Mage basics": the class buffs you know (Core.lua, ns.PRESETS). Hidden for other classes.
  presetButton = ns.T.Button(panel, LEFT_WIDTH, 22)
  presetButton:SetPoint("TOPLEFT", panel, "TOPLEFT", 16, top - 82)
  presetButton:SetScript("OnClick", function()
    ns.AddPreset()
  end)
  presetButton:SetScript("OnEnter", PresetTooltip)
  presetButton:SetScript("OnLeave", Hide)

  local addTitle = ns.T.Heading(panel, "Add a buff", RIGHT_WIDTH)
  addTitle:SetPoint("TOPLEFT", panel, "TOPLEFT", RIGHT_X, top - 60)

  searchBox = CreateFrame("EditBox", nil, panel, "InputBoxTemplate")
  searchBox:SetSize(RIGHT_WIDTH - 6, 22)
  searchBox:SetPoint("TOPLEFT", panel, "TOPLEFT", RIGHT_X + 6, top - 82)
  ns.T.EditBox(searchBox)
  searchBox:SetAutoFocus(false)
  searchBox:SetScript("OnEnterPressed", AddFromSearchBox)
  searchBox:SetScript("OnTextChanged", RefreshPicker)
  searchBox:HookScript("OnEditFocusGained", RefreshPicker)
  searchBox:HookScript("OnEditFocusLost", RefreshPicker)

  searchHint = searchBox:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
  searchHint:SetPoint("LEFT", 0, 0)
  searchHint:SetText("Search, or type a name or spell ID")

  status = panel:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
  status:SetPoint("TOP", subtitle, "BOTTOM", 0, -3)
  status:SetTextColor(1, 0.6, 0.2)

  trackedList = CreateList(16, top - 112, LEFT_WIDTH, TRACKED_ROW_HEIGHT)
  pickerList = CreateList(RIGHT_X, top - 112, RIGHT_WIDTH, ROW_HEIGHT)

  panel:SetScript("OnShow", function()
    spellbook = ns.GetSpellbook()
    ns.Scan()
    ns.RefreshOptions()
  end)

  if Settings and Settings.RegisterCanvasLayoutCategory and Settings.RegisterAddOnCategory then
    local category = Settings.RegisterCanvasLayoutCategory(panel, ns.TITLE)
    Settings.RegisterAddOnCategory(category)
    ns.optionsCategory = category
  elseif InterfaceOptions_AddCategory then
    InterfaceOptions_AddCategory(panel)
  end
end

function ns.OpenOptions()
  if ns.optionsCategory and Settings and Settings.OpenToCategory then
    local id = ns.optionsCategory.GetID and ns.optionsCategory:GetID() or ns.optionsCategory.ID
    Settings.OpenToCategory(id)
  elseif panel and InterfaceOptionsFrame_OpenToCategory then
    -- called twice: the first call only opens the frame on older clients
    InterfaceOptionsFrame_OpenToCategory(panel)
    InterfaceOptionsFrame_OpenToCategory(panel)
  end
end
