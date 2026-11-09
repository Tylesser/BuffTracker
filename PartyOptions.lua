local _, ns = ...

-- Options sub-page: Esc > Options > AddOns > Tylesser - Buff Tracker > Party buffs
-- Left: the group buffs you know, each with an on/off box. Right (paladins): blessing per class,
-- and per party member.

local ROW_HEIGHT = 26
local LEFT_X, LEFT_WIDTH = 16, 290
local RIGHT_X, RIGHT_WIDTH = 330, 250
local CYCLE_WIDTH = 96

local CLASSES = { "WARRIOR", "PALADIN", "HUNTER", "ROGUE", "PRIEST", "SHAMAN", "MAGE", "WARLOCK", "DRUID" }
if select(4, GetBuildInfo()) >= 30000 and select(4, GetBuildInfo()) < 40000 then
  table.insert(CLASSES, 2, "DEATHKNIGHT")
end
local UNITS = { "player", "party1", "party2", "party3", "party4" }

local panel, enabledCheck, soonCheck
local buffRows, buffEmpty = {}, nil
local blessingTitle, blessingEmpty, classRows, memberTitle, memberRows, memberEmpty = nil, nil, {}, nil, {}, nil

local function CheckBox(parent, label)
  local check = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
  local text = check.Text or check.text
  if not text then
    text = check:CreateFontString(nil, "OVERLAY")
    text:SetPoint("LEFT", check, "RIGHT", 2, 0)
  end
  text:SetFontObject("GameFontHighlight")
  text:SetText(label)
  check.label = text
  return check
end

local function ColoredClass(class, text)
  local color = RAID_CLASS_COLORS and RAID_CLASS_COLORS[class]
  if not color then
    return text
  end
  local function Byte(value)
    return math.floor(value * 255 + 0.5)
  end
  return string.format("|cff%02x%02x%02x%s|r", Byte(color.r), Byte(color.g), Byte(color.b), text)
end

local function ClassName(class)
  return (LOCALIZED_CLASS_NAMES_MALE and LOCALIZED_CLASS_NAMES_MALE[class]) or class
end

local function BlessingLabel(key)
  local family = key and ns.FAMILY[key]
  if family then
    return family.label
  end
  return "None"
end

-- Next value in: [by class], none, then each known blessing.
local function NextBlessing(current, withClassOption)
  local order = {}
  if withClassOption then
    order[#order + 1] = false
  end
  order[#order + 1] = "none"
  for _, family in ipairs(ns.KnownBlessings()) do
    order[#order + 1] = family.key
  end
  local currentValue = current
  if currentValue == nil then
    currentValue = withClassOption and false
  end
  if currentValue == nil or currentValue == false and not withClassOption then
    currentValue = "none"
  end
  for index, value in ipairs(order) do
    if value == currentValue then
      return order[index % #order + 1] or nil
    end
  end
  return order[1] or nil
end

local function CycleButton(parent)
  local button = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
  button:SetSize(CYCLE_WIDTH, 22)
  return button
end

local function GetBuffRow(index)
  local row = buffRows[index]
  if row then
    return row
  end
  row = CreateFrame("Frame", nil, panel)
  row:SetSize(LEFT_WIDTH, ROW_HEIGHT * 1.5)
  row:SetPoint("TOPLEFT", panel, "TOPLEFT", LEFT_X, -160 - (index - 1) * ROW_HEIGHT * 1.6)
  row.check = CreateFrame("CheckButton", nil, row, "UICheckButtonTemplate")
  row.check:SetPoint("TOPLEFT", -2, 2)
  row.check:SetScript("OnClick", function(self)
    ns.db.party.off[self:GetParent().family.key] = not self:GetChecked() or nil
    ns.PartyChanged()
  end)
  row.icon = row:CreateTexture(nil, "ARTWORK")
  row.icon:SetSize(20, 20)
  row.icon:SetPoint("LEFT", row.check, "RIGHT", 2, 0)
  row.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
  row.name = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  row.name:SetPoint("LEFT", row.icon, "RIGHT", 6, 0)
  row.name:SetPoint("RIGHT", row, "RIGHT", 0, 0)
  row.name:SetJustifyH("LEFT")
  row.reagent = row:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
  row.reagent:SetPoint("TOPLEFT", row.name, "BOTTOMLEFT", 0, -2)
  buffRows[index] = row
  return row
end

local function SpellIcon(name)
  if C_Spell and C_Spell.GetSpellTexture then
    return C_Spell.GetSpellTexture(name)
  end
  return GetSpellTexture(name)
end

local function RefreshBuffs()
  local used = 0
  for _, family in ipairs(ns.GROUP_BUFFS) do
    if ns.KnowsFamily(family) then
      used = used + 1
      local row = GetBuffRow(used)
      row.family = family
      row.check:SetChecked(ns.FamilyEnabled(family))
      local names = {}
      for _, spell in ipairs(family.spells) do
        if ns.KnowsSpell(spell.name) then
          names[#names + 1] = spell.name
        end
      end
      row.icon:SetTexture(SpellIcon(names[1]) or ns.DEFAULT_ICON)
      row.name:SetText(table.concat(names, ", or "))
      local first = family.spells[1]
      if ns.KnowsSpell(first.name) and first.reagents then
        row.reagent:SetText((ns.ReagentName(first) or "Reagent") .. ": " .. ns.ReagentCount(first))
      else
        row.reagent:SetText("")
      end
      row:Show()
    end
  end
  for index = used + 1, #buffRows do
    buffRows[index]:Hide()
  end
  buffEmpty:SetShown(used == 0)
end

local function GetClassRow(index)
  local row = classRows[index]
  if row then
    return row
  end
  row = CreateFrame("Frame", nil, panel)
  row:SetSize(RIGHT_WIDTH, ROW_HEIGHT)
  row:SetPoint("TOPLEFT", panel, "TOPLEFT", RIGHT_X, -160 - (index - 1) * ROW_HEIGHT)
  row.button = CycleButton(row)
  row.button:SetPoint("RIGHT", 0, 0)
  row.button:SetScript("OnClick", function(self)
    local class = self:GetParent().class
    local classes = ns.db.party.classes
    local current = classes[class] or ns.DEFAULT_BLESSINGS[class] or "none"
    classes[class] = NextBlessing(current, false) or "none"
    ns.PartyChanged()
  end)
  row.name = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
  row.name:SetPoint("LEFT", 4, 0)
  classRows[index] = row
  return row
end

local function GetMemberRow(index)
  local row = memberRows[index]
  if row then
    return row
  end
  row = CreateFrame("Frame", nil, panel)
  row:SetSize(RIGHT_WIDTH, ROW_HEIGHT)
  row.button = CycleButton(row)
  row.button:SetPoint("RIGHT", 0, 0)
  row.button:SetScript("OnClick", function(self)
    local members = ns.db.party.members
    local name = self:GetParent().memberName
    members[name] = NextBlessing(members[name], true)
    ns.PartyChanged()
  end)
  row.name = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
  row.name:SetPoint("LEFT", 4, 0)
  row.name:SetPoint("RIGHT", row.button, "LEFT", -4, 0)
  row.name:SetJustifyH("LEFT")
  row.name:SetWordWrap(false)
  memberRows[index] = row
  return row
end

local function RefreshBlessings()
  local known = #ns.KnownBlessings() > 0
  blessingEmpty:SetShown(not known)
  memberTitle:SetShown(known)
  local classes = ns.db.party.classes
  for index, class in ipairs(CLASSES) do
    local row = GetClassRow(index)
    row.class = class
    row.name:SetText(ColoredClass(class, ClassName(class)))
    row.button:SetText(BlessingLabel(classes[class] or ns.DEFAULT_BLESSINGS[class]))
    row:SetShown(known)
  end
  memberTitle:ClearAllPoints()
  memberTitle:SetPoint("TOPLEFT", panel, "TOPLEFT", RIGHT_X, -160 - #CLASSES * ROW_HEIGHT - 12)

  local used = 0
  if known then
    for _, unit in ipairs(UNITS) do
      local name = UnitExists(unit) and GetUnitName(unit, true)
      if name then
        used = used + 1
        local row = GetMemberRow(used)
        row:ClearAllPoints()
        row:SetPoint("TOPLEFT", memberTitle, "BOTTOMLEFT", 0, -4 - (used - 1) * ROW_HEIGHT)
        row.memberName = name
        local _, class = UnitClass(unit)
        row.name:SetText(ColoredClass(class, name))
        local own = ns.db.party.members[name]
        if own then
          row.button:SetText(BlessingLabel(own))
        else
          local byClass = ns.db.party.classes[class] or ns.DEFAULT_BLESSINGS[class]
          row.button:SetText("Class: " .. BlessingLabel(byClass))
        end
        row:Show()
      end
    end
  end
  for index = used + 1, #memberRows do
    memberRows[index]:Hide()
  end
  memberEmpty:SetShown(known and used <= 1 and not IsInGroup())
end

function ns.RefreshPartyOptions()
  if not (panel and panel:IsVisible()) then
    return
  end
  enabledCheck:SetChecked(ns.db.party.enabled)
  soonCheck:SetChecked(ns.db.party.soon)
  RefreshBuffs()
  RefreshBlessings()
end

function ns.CreatePartyOptions()
  panel = CreateFrame("Frame")
  panel.name = "Party buffs"
  panel.parent = ns.TITLE

  local title = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
  title:SetPoint("TOPLEFT", 16, -16)
  title:SetText("Party buffs")

  local subtitle = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  subtitle:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -8)
  subtitle:SetWidth(560)
  subtitle:SetJustifyH("LEFT")
  subtitle:SetText("Buttons next to your party frames for buffs a member is missing. Click one to cast it on them. "
    .. "Buttons can't appear or move during combat, so they update when combat ends.")

  enabledCheck = CheckBox(panel, "Show buff buttons next to party frames")
  enabledCheck:SetPoint("TOPLEFT", subtitle, "BOTTOMLEFT", -2, -8)
  enabledCheck:SetScript("OnClick", function(self)
    ns.db.party.enabled = self:GetChecked() and true or false
    ns.PartyChanged()
  end)

  soonCheck = CheckBox(panel, "Also show buffs that end within a minute")
  soonCheck:SetPoint("TOPLEFT", enabledCheck, "BOTTOMLEFT", 0, 2)
  soonCheck:SetScript("OnClick", function(self)
    ns.db.party.soon = self:GetChecked() and true or false
    ns.PartyChanged()
  end)

  local buffTitle = panel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  buffTitle:SetPoint("TOPLEFT", panel, "TOPLEFT", LEFT_X, -140)
  buffTitle:SetText("Your group buffs")

  buffEmpty = panel:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
  buffEmpty:SetPoint("TOPLEFT", buffTitle, "BOTTOMLEFT", 0, -8)
  buffEmpty:SetWidth(LEFT_WIDTH)
  buffEmpty:SetJustifyH("LEFT")
  buffEmpty:SetText("You don't know any group buffs yet (Arcane Intellect, Power Word: Fortitude, Divine Spirit, "
    .. "Shadow Protection, Mark of the Wild).")

  local note = panel:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
  note:SetPoint("TOPLEFT", panel, "TOPLEFT", LEFT_X, -160 - #ns.GROUP_BUFFS * ROW_HEIGHT * 1.6 - 8)
  note:SetWidth(LEFT_WIDTH)
  note:SetJustifyH("LEFT")
  note:SetText("The group spell is used when you can cast it. Without its reagent, the button casts the "
    .. "single-target spell instead.")

  blessingTitle = panel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  blessingTitle:SetPoint("TOPLEFT", panel, "TOPLEFT", RIGHT_X, -140)
  blessingTitle:SetText("Blessings by class")

  blessingEmpty = panel:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
  blessingEmpty:SetPoint("TOPLEFT", blessingTitle, "BOTTOMLEFT", 0, -8)
  blessingEmpty:SetWidth(RIGHT_WIDTH)
  blessingEmpty:SetJustifyH("LEFT")
  blessingEmpty:SetText("For paladins: choose a blessing for each class and party member.")

  memberTitle = panel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  memberTitle:SetText("Party members")

  memberEmpty = panel:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
  memberEmpty:SetPoint("TOPLEFT", memberTitle, "BOTTOMLEFT", 0, -4 - ROW_HEIGHT)
  memberEmpty:SetWidth(RIGHT_WIDTH)
  memberEmpty:SetJustifyH("LEFT")
  memberEmpty:SetText("Join a group to choose a blessing for each member. Their choice is kept by name.")

  panel:SetScript("OnShow", function()
    ns.RefreshKnown()
    ns.RefreshPartyOptions()
  end)

  if ns.optionsCategory and Settings and Settings.RegisterCanvasLayoutSubcategory then
    ns.partyCategory = Settings.RegisterCanvasLayoutSubcategory(ns.optionsCategory, panel, "Party buffs")
  elseif InterfaceOptions_AddCategory then
    InterfaceOptions_AddCategory(panel)
  end
end

function ns.OpenPartyOptions()
  if ns.partyCategory and Settings and Settings.OpenToCategory then
    local id = ns.partyCategory.GetID and ns.partyCategory:GetID() or ns.partyCategory.ID
    Settings.OpenToCategory(id)
  elseif panel and InterfaceOptionsFrame_OpenToCategory then
    InterfaceOptionsFrame_OpenToCategory(panel)
    InterfaceOptionsFrame_OpenToCategory(panel)
  end
end
