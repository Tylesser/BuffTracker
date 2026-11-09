local _, ns = ...

-- Buttons next to the party frames for group buffs a member is missing. Clicking one casts the
-- buff on that member. They are secure buttons: the game doesn't let addons show, hide, move or
-- change them in combat, so all of that happens out of combat. In combat they keep working as
-- they were, and a buff that lands on the member only dims its button.

local SIZE = 24
local GAP = 2
local MAX_PER_UNIT = 4
local SOON_SECONDS = 60
local REFRESH_SECONDS = 1
local UNITS = { "player", "party1", "party2", "party3", "party4" }
local NO_MANA = { WARRIOR = true, ROGUE = true, DEATHKNIGHT = true, DEMONHUNTER = true }

-- Buffs you can give your group. The first spell is preferred; when it can't be cast (usually a
-- missing reagent) the next one is used. Any of the spells counts as having the buff.
-- English spell names; reagent item IDs are only shown in the tooltip.
ns.GROUP_BUFFS = {
  { key = "intellect", manaOnly = true, spells = {
    { name = "Arcane Brilliance", reagents = { 17020 } }, { name = "Arcane Intellect" } } },
  { key = "fortitude", spells = {
    { name = "Prayer of Fortitude", reagents = { 17029, 17028 } }, { name = "Power Word: Fortitude" } } },
  { key = "spirit", manaOnly = true, spells = {
    { name = "Prayer of Spirit", reagents = { 17029 } }, { name = "Divine Spirit" } } },
  { key = "shadow", spells = {
    { name = "Prayer of Shadow Protection", reagents = { 17029 } }, { name = "Shadow Protection" } } },
  { key = "wild", spells = {
    { name = "Gift of the Wild", reagents = { 17026, 17021 } }, { name = "Mark of the Wild" } } },
}

-- Paladin blessings: one per member, chosen by class or per member in the options.
ns.BLESSINGS = {}
for _, blessing in ipairs({ "Might", "Wisdom", "Kings", "Salvation", "Light", "Sanctuary" }) do
  table.insert(ns.BLESSINGS, { key = blessing:lower(), label = blessing, blessing = true, spells = {
    { name = "Greater Blessing of " .. blessing, reagents = { 21177 } }, { name = "Blessing of " .. blessing } } })
end
ns.DEFAULT_BLESSINGS = {
  WARRIOR = "might", ROGUE = "might", HUNTER = "might", DEATHKNIGHT = "might",
  PALADIN = "wisdom", PRIEST = "wisdom", MAGE = "wisdom", WARLOCK = "wisdom", DRUID = "wisdom", SHAMAN = "wisdom",
}

ns.FAMILY = {}
for _, family in ipairs(ns.GROUP_BUFFS) do
  ns.FAMILY[family.key] = family
end
for _, family in ipairs(ns.BLESSINGS) do
  ns.FAMILY[family.key] = family
end

-- Spells the character knows, by lower-case name.
ns.known = {}

function ns.RefreshKnown()
  local known = {}
  for _, spell in ipairs(ns.GetSpellbook()) do
    known[spell.name:lower()] = true
  end
  ns.known = known
end

function ns.KnowsSpell(name)
  return ns.known[name:lower()] or false
end

function ns.KnowsFamily(family)
  for _, spell in ipairs(family.spells) do
    if ns.KnowsSpell(spell.name) then
      return true
    end
  end
  return false
end

function ns.KnownBlessings()
  local list = {}
  for _, family in ipairs(ns.BLESSINGS) do
    if ns.KnowsFamily(family) then
      list[#list + 1] = family
    end
  end
  return list
end

function ns.FamilyEnabled(family)
  return not ns.db.party.off[family.key]
end

-- Blessing family key for a unit, or nil. A member's own choice wins over their class.
function ns.BlessingFor(unit)
  local party = ns.db.party
  local name = GetUnitName(unit, true)
  local key = name and party.members[name]
  if not key then
    local _, class = UnitClass(unit)
    key = class and (party.classes[class] or ns.DEFAULT_BLESSINGS[class])
  end
  if key == "none" then
    return nil
  end
  return key
end

function ns.ReagentCount(spell)
  local count = 0
  local GetCount = (C_Item and C_Item.GetItemCount) or GetItemCount
  for _, id in ipairs(spell.reagents or {}) do
    count = count + (GetCount(id) or 0)
  end
  return count
end

function ns.ReagentName(spell)
  local id = spell.reagents and spell.reagents[1]
  if not id then
    return nil
  end
  if C_Item and C_Item.GetItemNameByID then
    return C_Item.GetItemNameByID(id)
  end
  return (GetItemInfo(id))
end

local function IsUsable(name)
  if C_Spell and C_Spell.IsSpellUsable then
    return C_Spell.IsSpellUsable(name)
  end
  return IsUsableSpell(name)
end

local function SpellIcon(name)
  if C_Spell and C_Spell.GetSpellTexture then
    return C_Spell.GetSpellTexture(name)
  end
  return GetSpellTexture(name)
end

local function InRange(name, unit)
  local result
  if C_Spell and C_Spell.IsSpellInRange then
    result = C_Spell.IsSpellInRange(name, unit)
  elseif IsSpellInRange then
    result = IsSpellInRange(name, unit)
  end
  return result ~= false and result ~= 0
end

-- The spell to cast for a buff: the first known one that can be cast. Being low on mana doesn't
-- count, as the cheaper spell wouldn't fix that. Returns the spell and whether it's a fallback.
function ns.ChooseSpell(family)
  local firstKnown
  for _, spell in ipairs(family.spells) do
    if ns.KnowsSpell(spell.name) then
      firstKnown = firstKnown or spell
      local usable, noMana = IsUsable(spell.name)
      if usable or noMana then
        return spell, spell ~= firstKnown
      end
    end
  end
  return firstKnown, false
end

-- Buffs read per unit: lower-case name -> expiration time (0 = no timer). nil = not read yet.
local auras = {}

local function ScanUnit(unit)
  local buffs, complete = ns.ReadBuffs(unit)
  if not complete and auras[unit] then
    return -- hidden right now: keep what we knew
  end
  local found = {}
  for _, buff in ipairs(buffs) do
    found[buff.name:lower()] = buff.expires
  end
  auras[unit] = complete and found or nil
end

-- Seconds left on any spell of the family; nil when the unit doesn't have it.
local function Remaining(unit, family)
  local found = auras[unit]
  local best
  for _, spell in ipairs(family.spells) do
    local expires = found[spell.name:lower()]
    if expires then
      if expires == 0 then
        return math.huge
      end
      best = math.max(best or 0, expires - GetTime())
    end
  end
  return best
end

local function FamiliesFor(unit)
  local list = {}
  local _, class = UnitClass(unit)
  for _, family in ipairs(ns.GROUP_BUFFS) do
    if ns.FamilyEnabled(family) and ns.KnowsFamily(family) and not (family.manaOnly and NO_MANA[class]) then
      list[#list + 1] = family
    end
  end
  local blessing = ns.FAMILY[ns.BlessingFor(unit) or ""]
  if blessing and ns.KnowsFamily(blessing) then
    list[#list + 1] = blessing
  end
  return list
end

-- Party frames ---------------------------------------------------------------------------------

local function FrameUnit(frame)
  local unit = frame.unit or frame.displayedUnit
  if not unit and frame.GetAttribute then
    unit = frame:GetAttribute("unit")
  end
  return type(unit) == "string" and unit or nil
end

-- Blizzard's party frames, raid-style party frames, raid frames (your own group) and ElvUI.
-- The player's own PlayerFrame isn't used: the icon row covers your own buffs.
local function CandidateFrames()
  local list = {}
  local function Add(frame)
    if frame and frame.IsVisible then
      list[#list + 1] = frame
    end
  end
  for i = 1, 5 do
    Add(_G["CompactPartyFrameMember" .. i])
  end
  for i = 1, 4 do
    Add(_G["PartyMemberFrame" .. i])
  end
  local pool = PartyFrame and PartyFrame.PartyMemberFramePool
  if pool and pool.EnumerateActive then
    pcall(function()
      for frame in pool:EnumerateActive() do
        Add(frame)
      end
    end)
  end
  for i = 1, 5 do
    Add(_G["ElvUF_PartyGroup1UnitButton" .. i])
  end
  for group = 1, 8 do
    for member = 1, 5 do
      Add(_G["CompactRaidGroup" .. group .. "Member" .. member])
    end
  end
  for i = 1, 40 do
    Add(_G["CompactRaidFrame" .. i])
  end
  return list
end

local function FindFrames()
  local frames = {}
  for _, frame in ipairs(CandidateFrames()) do
    if frame:IsVisible() then
      local frameUnit = FrameUnit(frame)
      if frameUnit and UnitExists(frameUnit) then
        for _, unit in ipairs(UNITS) do
          if not frames[unit] and UnitExists(unit) and UnitIsUnit(frameUnit, unit) then
            frames[unit] = frame
          end
        end
      end
    end
  end
  return frames
end

-- Buttons --------------------------------------------------------------------------------------

local buttons = {} -- buttons[unit index][1..MAX_PER_UNIT]
local dirty, sinceRefresh = true, 0

local function ShowTooltip(self)
  if not self.family then
    return
  end
  GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
  GameTooltip:AddLine(self.spell.name)
  local who = GetUnitName(self.unit, false) or self.unit
  local remaining = auras[self.unit] and Remaining(self.unit, self.family)
  if remaining then
    if remaining == math.huge then
      GameTooltip:AddLine(who .. " has it now.", 0.6, 0.6, 0.6)
    else
      GameTooltip:AddLine(string.format("Ends on %s in %d sec.", who, math.ceil(remaining)), 1, 1, 1)
    end
  else
    GameTooltip:AddLine("Missing on " .. who .. ".", 1, 0.3, 0.3)
  end
  if self.spell.reagents then
    GameTooltip:AddLine((ns.ReagentName(self.spell) or "Reagent") .. ": " .. ns.ReagentCount(self.spell), 1, 1, 1)
  end
  if self.fellBack then
    local preferred = self.family.spells[1]
    GameTooltip:AddLine("Can't cast " .. preferred.name .. ", so this casts " .. self.spell.name .. ".",
      1, 0.6, 0.2, true)
  end
  if self.family.blessing then
    GameTooltip:AddLine("Change blessings: /btrack party", 0.6, 0.6, 0.6)
  end
  GameTooltip:AddLine("Click to cast.", 0.6, 0.6, 0.6)
  GameTooltip:Show()
end

local function CreateButton()
  local button = CreateFrame("Button", nil, UIParent, "SecureActionButtonTemplate")
  button:SetSize(SIZE, SIZE)
  -- Newer clients run secure clicks on key down or up depending on a setting; they need both.
  local useKeyDown = C_CVar and C_CVar.GetCVar and C_CVar.GetCVar("ActionButtonUseKeyDown") ~= nil
  if useKeyDown then
    button:RegisterForClicks("AnyUp", "AnyDown")
  else
    button:RegisterForClicks("AnyUp")
  end
  button:SetAttribute("type", "spell")

  local backdrop = button:CreateTexture(nil, "BACKGROUND")
  backdrop:SetAllPoints()
  backdrop:SetColorTexture(0, 0, 0, 1)
  button.border = ns.T.DoubleBorder(button)
  button.icon = button:CreateTexture(nil, "ARTWORK")
  button.icon:SetPoint("TOPLEFT", 3, -3)
  button.icon:SetPoint("BOTTOMRIGHT", -3, 3)
  button.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
  button:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")

  button:SetScript("OnEnter", ShowTooltip)
  button:SetScript("OnLeave", function()
    GameTooltip:Hide()
  end)
  button:Hide()
  return button
end

function ns.SetupParty()
  local party = ns.db.party or {}
  ns.db.party = party
  if party.enabled == nil then
    party.enabled = true
  end
  party.soon = party.soon or false
  party.off = party.off or {}
  party.classes = party.classes or {}
  party.members = party.members or {}
  for index = 1, #UNITS do
    buttons[index] = {}
    for slot = 1, MAX_PER_UNIT do
      buttons[index][slot] = CreateButton()
    end
  end
  ns.RefreshKnown()
end

-- Colors only: allowed in combat.
local function UpdateLooks()
  for _, row in ipairs(buttons) do
    for _, button in ipairs(row) do
      if button:IsShown() and button.family then
        local unit, spell = button.unit, button.spell
        local has = auras[unit] and Remaining(unit, button.family)
        local done = has and not (ns.db.party.soon and has < SOON_SECONDS)
        local _, noMana = IsUsable(spell.name)
        local reachable = UnitIsConnected(unit) and not UnitIsDeadOrGhost(unit) and InRange(spell.name, unit)
        button.icon:SetDesaturated(done or false)
        if done then
          button:SetAlpha(0.4)
          ns.T.SetBorderColor(button.border, ns.T.GREY)
        else
          button:SetAlpha(1)
          ns.T.SetBorderColor(button.border, ns.T.GOLD_DEEP)
        end
        if not reachable then
          button.icon:SetVertexColor(1, 0.3, 0.3)
        elseif noMana then
          button.icon:SetVertexColor(0.4, 0.4, 1)
        else
          button.icon:SetVertexColor(1, 1, 1)
        end
      end
    end
  end
end

local function PlaceRow(row, frame, count)
  local frameX = (frame:GetCenter() or 0) * frame:GetEffectiveScale()
  local screenX = UIParent:GetCenter() * UIParent:GetEffectiveScale()
  local onRight = frameX < screenX -- buttons go on the side facing the middle of the screen
  for slot = 1, count do
    local button = row[slot]
    button:ClearAllPoints()
    if slot == 1 then
      if onRight then
        button:SetPoint("LEFT", frame, "RIGHT", GAP, 0)
      else
        button:SetPoint("RIGHT", frame, "LEFT", -GAP, 0)
      end
    elseif onRight then
      button:SetPoint("LEFT", row[slot - 1], "RIGHT", GAP, 0)
    else
      button:SetPoint("RIGHT", row[slot - 1], "LEFT", -GAP, 0)
    end
    button:SetFrameStrata(frame:GetFrameStrata())
    button:SetFrameLevel(frame:GetFrameLevel() + 10)
  end
end

function ns.UpdateParty()
  if not (ns.db and buttons[1]) then
    return
  end
  dirty, sinceRefresh = false, 0
  for _, unit in ipairs(UNITS) do
    if UnitExists(unit) then
      ScanUnit(unit)
    else
      auras[unit] = nil
    end
  end
  if InCombatLockdown() then
    dirty = true -- lay out again when combat ends
    UpdateLooks()
    return
  end

  local party = ns.db.party
  local frames = (party.enabled and IsInGroup()) and FindFrames() or {}
  for index, unit in ipairs(UNITS) do
    local needs = {}
    local frame = frames[unit]
    if frame and auras[unit] and UnitIsConnected(unit) and not UnitIsDeadOrGhost(unit) then
      for _, family in ipairs(FamiliesFor(unit)) do
        local remaining = Remaining(unit, family)
        if remaining == nil or (party.soon and remaining < SOON_SECONDS) then
          local spell, fellBack = ns.ChooseSpell(family)
          if spell and #needs < MAX_PER_UNIT then
            needs[#needs + 1] = { family = family, spell = spell, fellBack = fellBack }
          end
        end
      end
    end
    local row = buttons[index]
    for slot, button in ipairs(row) do
      local need = needs[slot]
      if need then
        button.unit, button.family, button.spell, button.fellBack = unit, need.family, need.spell, need.fellBack
        button:SetAttribute("unit", unit)
        button:SetAttribute("spell", need.spell.name)
        button.icon:SetTexture(SpellIcon(need.spell.name) or ns.DEFAULT_ICON)
        button:Show()
      else
        button.family = nil
        button:Hide()
      end
    end
    if #needs > 0 then
      PlaceRow(row, frame, #needs)
    end
  end
  UpdateLooks()
end

function ns.PartyChanged()
  dirty = true
  ns.RefreshPartyOptions()
end

local eventFrame = CreateFrame("Frame")
for _, event in ipairs({
  "GROUP_ROSTER_UPDATE", "PLAYER_ENTERING_WORLD", "PLAYER_REGEN_ENABLED", "SPELLS_CHANGED",
  "BAG_UPDATE_DELAYED", "UNIT_AURA", "UNIT_CONNECTION", "UNIT_FLAGS",
}) do
  pcall(eventFrame.RegisterEvent, eventFrame, event)
end
eventFrame:SetScript("OnEvent", function(_, event, unit)
  if not ns.db then
    return
  end
  if (event == "UNIT_AURA" or event == "UNIT_CONNECTION" or event == "UNIT_FLAGS")
    and not (unit == "player" or (type(unit) == "string" and unit:find("^party%d$"))) then
    return
  end
  if event == "SPELLS_CHANGED" then
    ns.RefreshKnown()
  end
  dirty = true
  if event == "GROUP_ROSTER_UPDATE" then
    ns.RefreshPartyOptions()
  end
end)

-- Called from the main tick: refreshes after events, and every second for timers, range and
-- frames that moved.
function ns.PartyTick(elapsed)
  sinceRefresh = sinceRefresh + elapsed
  if (dirty and not InCombatLockdown()) or sinceRefresh >= REFRESH_SECONDS then
    ns.UpdateParty()
  end
end
