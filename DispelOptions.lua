local _, ns = ...

-- Options sub-page: Esc > Options > AddOns > Tylesser - Buff Tracker > Dispels
-- Two check boxes (party frames, yourself) and the dispels you know with what each removes.

local LEFT_X, WIDTH = 16, 560
local ROW_HEIGHT = 26

local panel, partyCheck, selfCheck, listTitle, listEmpty
local rows = {}

local function SpellIcon(name)
  if C_Spell and C_Spell.GetSpellTexture then
    return C_Spell.GetSpellTexture(name)
  end
  return GetSpellTexture(name)
end

local function GetRow(index)
  local row = rows[index]
  if row then
    return row
  end
  row = CreateFrame("Frame", nil, panel)
  row:SetSize(WIDTH, ROW_HEIGHT)
  row:SetPoint("TOPLEFT", listTitle, "BOTTOMLEFT", 0, -8 - (index - 1) * ROW_HEIGHT)
  row.icon = row:CreateTexture(nil, "ARTWORK")
  row.icon:SetSize(22, 22)
  row.icon:SetPoint("LEFT", 0, 0)
  row.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
  row.name = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
  row.name:SetPoint("LEFT", row.icon, "RIGHT", 8, 0)
  rows[index] = row
  return row
end

function ns.RefreshDispelOptions()
  if not (panel and panel:IsVisible()) then
    return
  end
  partyCheck:SetChecked(ns.db.dispel.party)
  selfCheck:SetChecked(ns.db.dispel.self)
  local spells = ns.DispelSpells()
  for index, spell in ipairs(spells) do
    local row = GetRow(index)
    local types = {}
    for _, debuffType in ipairs(spell.typeList) do
      types[#types + 1] = ns.ColoredDebuffType(debuffType)
    end
    row.icon:SetTexture(SpellIcon(spell.name) or ns.DEFAULT_ICON)
    row.name:SetText(spell.name .. ": " .. table.concat(types, ", "))
    row:Show()
  end
  for index = #spells + 1, #rows do
    rows[index]:Hide()
  end
  listEmpty:SetShown(#spells == 0)
end

local function Changed()
  ns.PartyChanged()
  ns.UpdateSelfDispel()
  ns.RefreshDispelOptions()
end

local function Help(anchor, text)
  local help = panel:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
  help:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 26, 0)
  help:SetWidth(WIDTH - 26)
  help:SetJustifyH("LEFT")
  help:SetText(text)
  return help
end

function ns.CreateDispelOptions()
  panel = CreateFrame("Frame")
  panel.name = "Dispels"
  panel.parent = ns.TITLE

  ns.T.OptionsPage(panel, "Dispels", "A button for each debuff you can remove, like a poison or a curse. "
    .. "Click it to cast your dispel on that player.")

  partyCheck = ns.T.Check(panel, "Dispel buttons next to party frames")
  partyCheck:SetPoint("TOPLEFT", panel, "TOPLEFT", LEFT_X - 2, ns.T.OPTIONS_TOP)
  partyCheck:SetScript("OnClick", function(self)
    ns.db.dispel.party = self:GetChecked() and true or false
    Changed()
  end)
  local partyHelp = Help(partyCheck, "In a party, after the buff buttons. Not in raids: there the game would "
    .. "only let them show out of combat.")

  selfCheck = ns.T.Check(panel, "Dispel buttons for yourself, under the icon row")
  selfCheck:SetPoint("TOPLEFT", partyHelp, "BOTTOMLEFT", -26, -8)
  selfCheck:SetScript("OnClick", function(self)
    ns.db.dispel.self = self:GetChecked() and true or false
    Changed()
  end)
  local selfHelp = Help(selfCheck, "Also when you play alone.")

  local combat = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  combat:SetPoint("TOPLEFT", selfHelp, "BOTTOMLEFT", -24, -14)
  combat:SetWidth(WIDTH)
  combat:SetJustifyH("LEFT")
  combat:SetText("In combat the game doesn't let addons add or remove buttons. So as combat starts, each party "
    .. "member (and you) gets a spot for every dispel you know. It stays empty until a debuff you can remove "
    .. "shows up, but an empty spot still takes a click.")

  listTitle = ns.T.Heading(panel, "Your dispels", WIDTH)
  listTitle:SetPoint("TOPLEFT", combat, "BOTTOMLEFT", 0, -18)

  listEmpty = panel:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
  listEmpty:SetPoint("TOPLEFT", listTitle, "BOTTOMLEFT", 0, -8)
  listEmpty:SetWidth(WIDTH)
  listEmpty:SetJustifyH("LEFT")
  listEmpty:SetText("You don't know a spell that removes debuffs from others yet. Paladins (Purify, Cleanse), "
    .. "priests, druids, shamans and mages learn one, and on newer game versions monks and evokers too. New ones show up here as you learn them.")

  local note = panel:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
  note:SetPoint("TOPLEFT", listTitle, "BOTTOMLEFT", 0, -8 - 4 * ROW_HEIGHT - 8)
  note:SetWidth(WIDTH)
  note:SetJustifyH("LEFT")
  note:SetText("When two of your spells remove the same debuff type, the button uses the better one, like Cleanse "
    .. "over Purify. The button shows the debuff's icon, with a border in its type's color.")

  panel:SetScript("OnShow", function()
    ns.RefreshKnown()
    ns.RefreshDispelOptions()
  end)

  if ns.optionsCategory and Settings and Settings.RegisterCanvasLayoutSubcategory then
    ns.dispelCategory = Settings.RegisterCanvasLayoutSubcategory(ns.optionsCategory, panel, "Dispels")
  elseif InterfaceOptions_AddCategory then
    InterfaceOptions_AddCategory(panel)
  end
end

function ns.OpenDispelOptions()
  if ns.dispelCategory and Settings and Settings.OpenToCategory then
    local id = ns.dispelCategory.GetID and ns.dispelCategory:GetID() or ns.dispelCategory.ID
    Settings.OpenToCategory(id)
  elseif panel and InterfaceOptionsFrame_OpenToCategory then
    InterfaceOptionsFrame_OpenToCategory(panel)
    InterfaceOptionsFrame_OpenToCategory(panel)
  end
end
