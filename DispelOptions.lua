local _, ns = ...
local L = ns.L

-- Options sub-page: Esc > Options > AddOns > Tylesser - Buff Tracker > Dispels
-- Two check boxes (party frames, yourself) and the dispels you know with what each removes.

local LEFT_X, WIDTH = 16, 560
local ROW_HEIGHT = 26

local panel, partyCheck, selfCheck, combatCheck, listTitle, listEmpty
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
  combatCheck:SetChecked(ns.db.dispel.combat)
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
  panel.name = L["Dispels"]
  panel.parent = ns.TITLE

  ns.T.OptionsPage(panel, L["Dispels"], L["A button for each debuff you can remove, like a poison or a curse. Click it to cast your dispel on that player."])

  partyCheck = ns.T.Check(panel, L["Dispel buttons next to party frames"])
  partyCheck:SetPoint("TOPLEFT", panel, "TOPLEFT", LEFT_X - 2, ns.T.OPTIONS_TOP)
  partyCheck:SetScript("OnClick", function(self)
    ns.db.dispel.party = self:GetChecked() and true or false
    Changed()
  end)
  local partyHelp = Help(partyCheck, L["In a party after the buff buttons, in a raid in the corner of the raid frames."])

  selfCheck = ns.T.Check(panel, L["Dispel buttons for yourself, under the icon row"])
  selfCheck:SetPoint("TOPLEFT", partyHelp, "BOTTOMLEFT", -26, -8)
  selfCheck:SetScript("OnClick", function(self)
    ns.db.dispel.self = self:GetChecked() and true or false
    Changed()
  end)
  local selfHelp = Help(selfCheck, L["Also when you play alone."])

  combatCheck = ns.T.Check(panel, L["Show dispel icons in combat"])
  combatCheck:SetPoint("TOPLEFT", selfHelp, "BOTTOMLEFT", -26, -8)
  combatCheck:SetScript("OnClick", function(self)
    ns.db.dispel.combat = self:GetChecked() and true or false
    Changed()
  end)
  local combatHelp = Help(combatCheck, L["During a fight the game doesn't let addons add or move clickable buttons, so a debuff that shows up then gets a plain icon in the same place instead. It takes no clicks. Buttons that were there before the fight keep working."])

  listTitle = ns.T.Heading(panel, L["Your dispels"], WIDTH)
  listTitle:SetPoint("TOPLEFT", combatHelp, "BOTTOMLEFT", -24, -18)

  listEmpty = panel:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
  listEmpty:SetPoint("TOPLEFT", listTitle, "BOTTOMLEFT", 0, -8)
  listEmpty:SetWidth(WIDTH)
  listEmpty:SetJustifyH("LEFT")
  listEmpty:SetText(L["You don't know a spell that removes debuffs from others yet. Paladins (%s, %s), priests, druids, shamans and mages learn one, and on newer game versions monks and evokers too. New ones show up here as you learn them."]
    :format(ns.LocalSpell("Purify"), ns.LocalSpell("Cleanse")))

  local note = panel:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
  note:SetPoint("TOPLEFT", listTitle, "BOTTOMLEFT", 0, -8 - 4 * ROW_HEIGHT - 8)
  note:SetWidth(WIDTH)
  note:SetJustifyH("LEFT")
  note:SetText(L["When two of your spells remove the same debuff type, the button uses the better one, like %s over %s. The button shows the debuff's icon, with a border in its type's color."]
    :format(ns.LocalSpell("Cleanse"), ns.LocalSpell("Purify")))

  panel:SetScript("OnShow", function()
    ns.RefreshKnown()
    ns.RefreshDispelOptions()
  end)

  -- a page under Buff Tracker's in Tylesser's settings window (Tylesser.lua, 2026-11-28)
  ns.dispelCategory = ns.T.RegisterOptions(panel, L["Dispels"], ns.optionsCategory)
end

function ns.OpenDispelOptions()
  ns.T.OpenOptions(ns.dispelCategory)
end
