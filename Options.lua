local _, ns = ...
local L = ns.L

-- Options page: Esc > Options > AddOns > Tylesser - Buff Tracker
-- Left: the tracked buffs. Right: buffs on the character and spells from the spellbook to add.

local ROW_HEIGHT = 26
local TRACKED_ROW_HEIGHT = 50 -- two lines: name and "when" on top, item and alert below
local LEFT_WIDTH = 270
local RIGHT_X = 330
local RIGHT_WIDTH = 240

local KEY_X, KEY_WIDTH = RIGHT_X + RIGHT_WIDTH + 30, 240 -- a third column: the next buff key (NextBuff.lua)

local panel, lockCheck, clickCheck, shapeButton, sizeText, searchBox, searchHint, status, presetButton, rowWhere
local keyButton
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
  GameTooltip:AddLine(L["When to show this buff"])
  GameTooltip:AddLine(L["When missing: only while it's not on you."], 1, 1, 1)
  GameTooltip:AddLine(L["When active: only while it's on you."], 1, 1, 1)
  GameTooltip:AddLine(L["Always: dimmed with a red border while it's missing."], 1, 1, 1)
  GameTooltip:AddLine(L["Click to change."], 0.6, 0.6, 0.6)
  GameTooltip:Show()
end

local function Hide()
  GameTooltip:Hide()
end

local function ItemTooltip(self)
  local entry = self:GetParent().entry
  GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
  GameTooltip:AddLine(L["Item to use"])
  GameTooltip:AddLine(L["Clicking the icon uses this item, like a food for Well Fed or an elixir."], 1, 1, 1, true)
  if entry.slot then
    GameTooltip:AddLine(L["For a weapon enchant: an oil, poison or sharpening stone, put on this weapon."], 1, 1, 1, true)
  else
    GameTooltip:AddLine(L["Without one, a bag item named after the buff is used when you don't know its spell."],
      1, 1, 1, true)
  end
  GameTooltip:AddLine(L["Click: next usable item in your bags. Right-click: none."], 0.6, 0.6, 0.6, true)
  -- (the command takes the entry's own name: for weapon enchants the English one)
  GameTooltip:AddLine(L["Or type %s = <item name>"]:format("/btrack item " .. entry.name), 0.6, 0.6, 0.6, true)
  GameTooltip:Show()
end

local function AlertTooltip(self)
  GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
  GameTooltip:AddLine(L["Alert"])
  GameTooltip:AddLine(L["Play a sound and flash the icon when this buff drops during combat."], 1, 1, 1, true)
  GameTooltip:AddLine(L["Only works while the game lets addons see your buffs in combat."], 0.6, 0.6, 0.6, true)
  GameTooltip:Show()
end

-- "Use: Roasted Quail (4)", "Use: Elixir of the Mongoose (auto)", or "Use item: none".
local function ItemLabel(entry)
  local id, auto = ns.ItemFor(entry)
  if not id then
    return L["Use item: none"]
  end
  local name = ns.ItemName(id) or L["item %s"]:format(id)
  if auto then
    return L["Use: %s (auto)"]:format(name)
  end
  return L["Use: %s (%d)"]:format(name, ns.ItemCount(id))
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
  row.item = ns.T.Button(row, 132, 20)
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

  row.alert = ns.T.Check(row, L["Alert"], "GameFontHighlightSmall")
  row.alert:SetPoint("LEFT", row.item, "RIGHT", 4, 0)
  row.alert:SetHitRectInsets(0, -(row.alert.Text:GetStringWidth() + 4), 0, 0)
  row.alert:SetScript("OnClick", function(self)
    self:GetParent().entry.alert = self:GetChecked() and true or nil
  end)
  row.alert:SetScript("OnEnter", AlertTooltip)
  row.alert:SetScript("OnLeave", Hide)

  -- where and when it shows (ConditionsOptions.lua): the row's rules, or its own
  row.where = ns.T.Button(row, 52, 20, L["Where"])
  row.where:SetPoint("TOPRIGHT", 0, -26)
  row.where:SetScript("OnClick", function(self)
    ns.OpenConditions(self:GetParent().entry, self)
  end)
  row.where:SetScript("OnEnter", function(self)
    ns.ConditionsTooltip(self, self:GetParent().entry)
  end)
  row.where:SetScript("OnLeave", Hide)

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
    row.name:SetText(ns.EntryName(entry))
    row.mode:SetText(ns.MODE_LABELS[entry.mode])
    row.item:SetText(ItemLabel(entry))
    row.alert:SetChecked(entry.alert or false)
    -- green text: the buff has its own rules (the tooltip says which)
    row.where.textColor = entry.conditions and { 0.25, 1, 0.25 } or nil
    local color = row.where.textColor or ns.T.GOLD
    row.where.label:SetTextColor(color[1], color[2], color[3])
    row:Show()
    used = index
  end
  Finish(trackedList, used, L["Nothing tracked yet. Pick a buff from the list on the right."])
end

local function RefreshPicker()
  local filter = strtrim(searchBox:GetText()):lower()
  local used = 0
  local seen = {}

  -- label: the text shown and searched, when it differs from the name (weapon enchant entries)
  local function Add(name, icon, tag, weaponSlot, label)
    local key = name:lower()
    if seen[key] or ns.IsTracked(name) then
      return
    end
    seen[key] = true
    if filter ~= "" and not key:find(filter, 1, true) and not (label and label:lower():find(filter, 1, true)) then
      return
    end
    used = used + 1
    local row = GetPickerRow(used)
    row.spellName, row.spellIcon, row.weaponSlot = name, icon, weaponSlot
    SetIcon(row.icon, icon)
    row.name:SetText(label or name)
    row.tag:SetText(tag)
    row:Show()
  end

  for _, buff in ipairs(ns.buffs) do
    Add(buff.name, buff.icon, L["on you"])
  end
  for _, spell in ipairs(spellbook) do
    Add(spell.name, spell.icon, "")
  end
  for _, slot in ipairs(ns.WEAPON_SLOTS) do
    Add(ns.WEAPON_NAMES[slot], GetInventoryItemTexture and GetInventoryItemTexture("player", slot), L["weapon"], slot,
      ns.WEAPON_LABELS[slot])
  end
  Finish(pickerList, used, L["No matches. Press Enter to track this name anyway. It must match the buff's name exactly."])

  searchHint:SetShown(searchBox:GetText() == "" and not searchBox:HasFocus())
  if ns.scanComplete then
    status:SetText("")
  else
    status:SetText(L["The game is hiding your buffs right now. They'll update when it stops."])
  end
end

function ns.RefreshOptions()
  ns.RefreshConditions()
  if not (panel and panel:IsVisible()) then
    return
  end
  lockCheck:SetChecked(ns.db.locked)
  clickCheck:SetChecked(ns.db.clickToCast)
  sizeText:SetText(L["Icon size: %d"]:format(ns.db.iconSize))
  shapeButton:SetText(L["Shape: %s"]:format(ns.SHAPE_LABELS[ns.db.iconShape] or L["Square"]))
  local preset = ns.PresetBuffs()
  presetButton:SetText(L["Add %s basics"]:format(UnitClass("player") or L["class"]))
  presetButton:SetShown(preset ~= nil)
  presetButton:SetEnabled(preset ~= nil and #preset > 0)
  keyButton:SetText(ns.NextKeyText(keyButton))
  RefreshTracked()
  RefreshPicker()
end

local function PresetTooltip(self)
  local list = ns.PresetBuffs() or {}
  GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
  GameTooltip:AddLine(self:GetText())
  if #list > 0 then
    GameTooltip:AddLine(L["Adds: %s"]:format(table.concat(list, ", ")), 1, 1, 1, true)
  else
    GameTooltip:AddLine(L["You already track the basic buffs of your class that you know."], 1, 1, 1, true)
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
    L["Choose the buffs to watch. The list is saved per character."])

  lockCheck = ns.T.Check(panel, L["Lock position (untick to drag the icons)"])
  lockCheck:SetPoint("TOPLEFT", panel, "TOPLEFT", 14, top)
  lockCheck:SetScript("OnClick", function(self)
    ns.SetLocked(self:GetChecked() and true or false)
  end)

  clickCheck = ns.T.Check(panel, L["Click icons to cast (out of combat)"])
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

  -- one key for the next missing buff (NextBuff.lua)
  local keyLabel = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
  keyLabel:SetPoint("TOPLEFT", panel, "TOPLEFT", KEY_X, top - 4)
  keyLabel:SetText(L["Key: next missing buff"])
  keyButton = ns.T.Button(panel, 110, 22, "")
  keyButton:SetPoint("TOPLEFT", keyLabel, "BOTTOMLEFT", 0, -6)
  ns.SetupNextKeyButton(keyButton, ns.RefreshOptions)
  local keyHelp = panel:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
  keyHelp:SetPoint("TOPLEFT", keyButton, "BOTTOMLEFT", 0, -6)
  keyHelp:SetWidth(KEY_WIDTH)
  keyHelp:SetJustifyH("LEFT")
  keyHelp:SetText(L["Casts the first missing buff of your icon row on you, or uses its item, like a click on its icon. Out of combat only."]
    .. " " .. L["In a macro: %s"]:format("/click " .. ns.NEXT_BUTTON_NAME))

  local trackedTitle = ns.T.Heading(panel, L["Tracked buffs"], LEFT_WIDTH)
  trackedTitle:SetPoint("TOPLEFT", panel, "TOPLEFT", 16, top - 60)

  -- "Add Mage basics": the class buffs you know (Core.lua, ns.PRESETS). Hidden for other classes.
  -- where and when the whole row shows (ConditionsOptions.lua)
  rowWhere = ns.T.Button(panel, 132, 22, L["Where the row shows"])
  rowWhere:SetPoint("TOPLEFT", panel, "TOPLEFT", 16, top - 82)
  rowWhere:SetScript("OnClick", function(self)
    ns.OpenConditions("row", self)
  end)
  rowWhere:SetScript("OnEnter", function(self)
    ns.ConditionsTooltip(self, "row")
  end)
  rowWhere:SetScript("OnLeave", Hide)

  presetButton = ns.T.Button(panel, LEFT_WIDTH - 138, 22)
  presetButton:SetPoint("TOPLEFT", panel, "TOPLEFT", 16 + 138, top - 82)
  presetButton:SetScript("OnClick", function()
    ns.AddPreset()
  end)
  presetButton:SetScript("OnEnter", PresetTooltip)
  presetButton:SetScript("OnLeave", Hide)

  local addTitle = ns.T.Heading(panel, L["Add a buff"], RIGHT_WIDTH)
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
  searchHint:SetText(L["Search, or type a name or spell ID"])


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

  -- shown in Tylesser's own settings window (Tylesser.lua T.RegisterOptions, 2026-11-28)
  ns.optionsCategory = ns.T.RegisterOptions(panel, ns.TITLE)
end

function ns.OpenOptions()
  ns.T.OpenOptions(ns.optionsCategory)
end
