local _, ns = ...

-- Options page: Esc > Options > AddOns > Tylesser - Buff Tracker
-- Left: the tracked buffs. Right: buffs on the character and spells from the spellbook to add.

local ROW_HEIGHT = 26
local LEFT_WIDTH = 270
local RIGHT_X = 330
local RIGHT_WIDTH = 240

local panel, lockCheck, sizeText, searchBox, searchHint, status
local trackedList, pickerList
local spellbook = {}

local function SetIcon(texture, icon)
  texture:SetTexture(icon or ns.DEFAULT_ICON)
  texture:SetTexCoord(0.08, 0.92, 0.08, 0.92)
end

local function CreateList(x, y, width)
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
  return { scroll = scroll, content = content, empty = empty, rows = {}, width = width }
end

local function Finish(list, used, emptyText)
  for index = used + 1, #list.rows do
    list.rows[index]:Hide()
  end
  list.empty:SetText(used == 0 and emptyText or "")
  list.content:SetHeight(math.max(used * ROW_HEIGHT, ROW_HEIGHT))
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

local function GetTrackedRow(index)
  local row = trackedList.rows[index]
  if row then
    return row
  end
  row = CreateFrame("Frame", nil, trackedList.content)
  row:SetSize(trackedList.width, ROW_HEIGHT)
  row:SetPoint("TOPLEFT", 0, -(index - 1) * ROW_HEIGHT)

  row.icon = row:CreateTexture(nil, "ARTWORK")
  row.icon:SetSize(22, 22)
  row.icon:SetPoint("LEFT", 2, 0)

  row.remove = ns.T.Button(row, 22, 22, "X")
  row.remove:SetPoint("RIGHT", 0, 0)
  row.remove:SetScript("OnClick", function(self)
    ns.RemoveBuff(self:GetParent().entry.name)
  end)

  row.mode = ns.T.Button(row, 96, 22)
  row.mode:SetPoint("RIGHT", row.remove, "LEFT", -2, 0)
  row.mode:SetScript("OnClick", function(self)
    ns.CycleMode(self:GetParent().entry)
  end)
  row.mode:SetScript("OnEnter", ModeTooltip)
  row.mode:SetScript("OnLeave", function()
    GameTooltip:Hide()
  end)

  row.name = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  row.name:SetPoint("LEFT", row.icon, "RIGHT", 6, 0)
  row.name:SetPoint("RIGHT", row.mode, "LEFT", -4, 0)
  row.name:SetJustifyH("LEFT")
  row.name:SetWordWrap(false)

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
    ns.AddBuff(self.spellName, self.spellIcon)
  end)

  pickerList.rows[index] = row
  return row
end

local function RefreshTracked()
  local used = 0
  for index, entry in ipairs(ns.db.tracked) do
    local row = GetTrackedRow(index)
    row.entry = entry
    SetIcon(row.icon, entry.icon)
    row.name:SetText(entry.name)
    row.mode:SetText(ns.MODE_LABELS[entry.mode])
    row:Show()
    used = index
  end
  Finish(trackedList, used, "Nothing tracked yet. Pick a buff from the list on the right.")
end

local function RefreshPicker()
  local filter = strtrim(searchBox:GetText()):lower()
  local used = 0
  local seen = {}

  local function Add(name, icon, tag)
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
    row.spellName, row.spellIcon = name, icon
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
  sizeText:SetText("Icon size: " .. ns.db.iconSize)
  RefreshTracked()
  RefreshPicker()
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

  local smaller = CreateSizeButton("-", -2)
  smaller:SetPoint("TOPLEFT", panel, "TOPLEFT", RIGHT_X, top)
  sizeText = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
  sizeText:SetPoint("LEFT", smaller, "RIGHT", 6, 0)
  sizeText:SetWidth(100)
  local larger = CreateSizeButton("+", 2)
  larger:SetPoint("LEFT", sizeText, "RIGHT", 6, 0)

  local trackedTitle = ns.T.Heading(panel, "Tracked buffs", LEFT_WIDTH)
  trackedTitle:SetPoint("TOPLEFT", panel, "TOPLEFT", 16, top - 36)

  local addTitle = ns.T.Heading(panel, "Add a buff", RIGHT_WIDTH)
  addTitle:SetPoint("TOPLEFT", panel, "TOPLEFT", RIGHT_X, top - 36)

  searchBox = CreateFrame("EditBox", nil, panel, "InputBoxTemplate")
  searchBox:SetSize(RIGHT_WIDTH - 6, 22)
  searchBox:SetPoint("TOPLEFT", panel, "TOPLEFT", RIGHT_X + 6, top - 58)
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

  trackedList = CreateList(16, top - 60, LEFT_WIDTH)
  pickerList = CreateList(RIGHT_X, top - 88, RIGHT_WIDTH)

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
