local _, ns = ...

-- Dispels: a button for each debuff you can remove, next to party frames (Party.lua) and under
-- your own icon row (here). Click it to cast the dispel on that member, or on yourself.
-- Which debuffs you can remove follows the spells you know: a paladin with only Purify gets
-- buttons for Poison and Disease, and once they learn Cleanse also for Magic.
--
-- Combat: the game doesn't let addons show, hide or change clickable buttons in combat, yet that
-- is when dispels matter. So as combat starts (still allowed while PLAYER_REGEN_DISABLED runs)
-- every member, and you, get a button for each dispel you know, invisible (alpha 0) until a
-- debuff it removes shows up. Changing the alpha and the icon is allowed in combat. When combat
-- ends, the buttons nothing needs go away again.

local INTERFACE = select(4, GetBuildInfo()) or 0
-- Mists of Pandaria and later: talents and specs change what a dispel removes, so there the game
-- itself says which debuffs you can remove (the "RAID" aura filter).
local MODERN = INTERFACE >= 50000
local GAP = 6
local BELOW_ROW = 16 -- room for the timer text under the icon row

local function Spell(name, ...)
  local types, list = {}, { ... }
  for _, debuffType in ipairs(list) do
    types[debuffType] = true
  end
  return { name = name, types = types, typeList = list }
end

-- Dispels you can cast on others, best first. English spell names, matched by name like the
-- buffs, so every rank counts. A spell that removes nothing an earlier known one doesn't is left
-- out (Purify once you know Cleanse, Cure Disease once you know Abolish Disease).
if MODERN then
  ns.DISPELS = {
    Spell("Cleanse", "Magic", "Poison", "Disease"),          -- paladin (Holy)
    Spell("Cleanse Toxins", "Poison", "Disease"),            -- paladin
    Spell("Purify", "Magic", "Disease"),                     -- priest
    Spell("Purify Disease", "Disease"),                      -- priest (Shadow)
    Spell("Nature's Cure", "Magic", "Curse", "Poison"),      -- druid (Restoration)
    Spell("Remove Corruption", "Curse", "Poison"),           -- druid
    Spell("Purify Spirit", "Magic", "Curse"),                -- shaman (Restoration)
    Spell("Cleanse Spirit", "Curse"),                        -- shaman
    Spell("Detox", "Magic", "Poison", "Disease"),            -- monk
    Spell("Naturalize", "Magic", "Poison"),                  -- evoker (Preservation)
    Spell("Cauterizing Flame", "Curse", "Poison", "Disease", "Bleed"), -- evoker
    Spell("Expunge", "Poison"),                              -- evoker
    Spell("Remove Curse", "Curse"),                          -- mage
  }
else
  -- Classic Era, WoW Forever, TBC and Wrath
  ns.DISPELS = {
    Spell("Cleanse", "Magic", "Poison", "Disease"),          -- paladin
    Spell("Purify", "Poison", "Disease"),                    -- paladin
    Spell("Dispel Magic", "Magic"),                          -- priest
    Spell("Abolish Disease", "Disease"),                     -- priest
    Spell("Cure Disease", "Disease"),                        -- priest, shaman
    Spell("Cleanse Spirit", "Curse", "Poison", "Disease"),   -- shaman (Wrath talent)
    Spell("Cure Toxins", "Poison", "Disease"),               -- shaman (Wrath)
    Spell("Remove Curse", "Curse"),                          -- druid, mage (TBC+)
    Spell("Remove Lesser Curse", "Curse"),                   -- mage
    Spell("Abolish Poison", "Poison"),                       -- druid
    Spell("Cure Poison", "Poison"),                          -- druid, shaman
  }
end
ns.DISPEL_FILTER = MODERN and "HARMFUL|RAID" or "HARMFUL"

-- Border colors, as on Blizzard's own debuff borders.
ns.DEBUFF_COLORS = {
  Magic = { 0.2, 0.6, 1 }, Curse = { 0.6, 0, 1 }, Disease = { 0.6, 0.4, 0 }, Poison = { 0, 0.6, 0 },
}
local OTHER_COLOR = { 0.8, 0, 0 }

function ns.DebuffColor(debuffType)
  return ns.DEBUFF_COLORS[debuffType] or OTHER_COLOR
end

local function ColoredType(debuffType)
  local color = ns.DebuffColor(debuffType)
  local function Byte(value)
    return math.floor(value * 255 + 0.5)
  end
  return string.format("|cff%02x%02x%02x%s|r", Byte(color[1]), Byte(color[2]), Byte(color[3]), debuffType)
end
ns.ColoredDebuffType = ColoredType

-- The dispels you know that add something, best first. Worked out again whenever the known spells
-- change (ns.RefreshKnown makes a new ns.known table).
local cachedFor, cached = nil, {}
function ns.DispelSpells()
  if cachedFor ~= ns.known then
    cachedFor, cached = ns.known, {}
    local covered = {}
    for _, spell in ipairs(ns.DISPELS) do
      if ns.KnowsSpell(spell.name) then
        local adds = false
        for _, debuffType in ipairs(spell.typeList) do
          adds = adds or not covered[debuffType]
        end
        if adds then
          cached[#cached + 1] = spell
          for _, debuffType in ipairs(spell.typeList) do
            covered[debuffType] = true
          end
        end
      end
    end
  end
  return cached
end

local function SpellForType(debuffType)
  for _, spell in ipairs(ns.DispelSpells()) do
    if spell.types[debuffType] then
      return spell
    end
  end
end

-- debuffs (from ns.ReadDebuffs with ns.DISPEL_FILTER) -> { [spell] = { debuff, ... } }: what each
-- of your dispels would remove. A type none of your spells lists gets no button.
function ns.RemovableDebuffs(debuffs)
  local bySpell = {}
  for _, debuff in ipairs(debuffs or {}) do
    local spell = SpellForType(debuff.type)
    if spell then
      local list = bySpell[spell]
      if not list then
        list = {}
        bySpell[spell] = list
      end
      list[#list + 1] = debuff
    end
  end
  return bySpell
end

-- Tooltip of a dispel button. who: "You" or the member's name.
function ns.DispelTooltip(owner, spell, who, list)
  GameTooltip:SetOwner(owner, "ANCHOR_RIGHT")
  GameTooltip:AddLine(spell.name)
  if list and #list > 0 then
    for _, debuff in ipairs(list) do
      GameTooltip:AddLine(string.format("%s %s %s: %s", who, who == "You" and "have" or "has",
        ColoredType(debuff.type), debuff.name), 1, 1, 1)
    end
    GameTooltip:AddLine("Click to remove it.", 0.6, 0.6, 0.6)
  else
    local types = {}
    for _, debuffType in ipairs(spell.typeList) do
      types[#types + 1] = ColoredType(debuffType)
    end
    GameTooltip:AddLine("Nothing to remove right now. Removes " .. table.concat(types, ", ") .. ".", 0.6, 0.6, 0.6,
      true)
  end
  GameTooltip:Show()
end

function ns.SetupDispel()
  local dispel = ns.db.dispel or {}
  ns.db.dispel = dispel
  if dispel.party == nil then
    dispel.party = true
  end
  if dispel.self == nil then
    dispel.self = true
  end
end

-- Your own dispel buttons ------------------------------------------------------------------------
-- A row under the icon row, one button per dispel you know, placed by the row's anchor. They're
-- on UIParent, like the click overlays, so the icon row stays free to change in combat.

local selfButtons = {}
local selfRemovable = {}

local function SelfTooltip(self)
  if self.spell and self:GetAlpha() > 0 then
    ns.DispelTooltip(self, self.spell, "You", selfRemovable[self.spell])
  end
end

local function GetSelfButton(index)
  local button = selfButtons[index]
  if not button then
    button = ns.NewSecureButton(UIParent)
    button:SetAttribute("unit", "player")
    button:SetScript("OnEnter", SelfTooltip)
    button:SetScript("OnLeave", function()
      GameTooltip:Hide()
    end)
    selfButtons[index] = button
  end
  return button
end

local function IsUsable(name)
  if C_Spell and C_Spell.IsSpellUsable then
    return C_Spell.IsSpellUsable(name)
  end
  return IsUsableSpell(name)
end

-- Alpha, icon and colors: allowed in combat.
local function SelfLooks()
  for _, button in ipairs(selfButtons) do
    if button:IsShown() and button.spell then
      local list = selfRemovable[button.spell]
      if list then
        local debuff = list[1]
        button.icon:SetTexture(debuff.icon or ns.DEFAULT_ICON)
        ns.SetFrameColor(button, ns.DebuffColor(debuff.type))
        local _, noMana = IsUsable(button.spell.name)
        if noMana then
          button.icon:SetVertexColor(0.4, 0.4, 1)
        else
          button.icon:SetVertexColor(1, 1, 1)
        end
        button:SetAlpha(1)
      else
        button:SetAlpha(0) -- in combat, when it can't be hidden
      end
    end
  end
end

-- combatStart: called as combat starts, so every dispel gets a button (see the top of the file).
function ns.UpdateSelfDispel(combatStart)
  if not ns.db then
    return
  end
  local spells = ns.DispelSpells()
  selfRemovable = (ns.db.dispel.self and #spells > 0)
    and ns.RemovableDebuffs(ns.ReadDebuffs("player", ns.DISPEL_FILTER)) or {}
  if not InCombatLockdown() then
    local anchor = ns.RowAnchor and ns.RowAnchor()
    local x, y
    if anchor and ns.db.dispel.self and not ns.IsRowUnlocked() then
      x, y = anchor:GetCenter()
    end
    local size = ns.db.iconSize
    for index, spell in ipairs(spells) do
      local wanted = x and (combatStart or selfRemovable[spell])
      local button = wanted and GetSelfButton(index) or selfButtons[index]
      if wanted then
        local px = x + (index - (#spells + 1) / 2) * (size + GAP)
        local py = y - size - BELOW_ROW
        if not (button:IsShown() and button.spell == spell and button.px == px and button.py == py
          and button.size == size) then
          button.spell, button.px, button.py, button.size = spell, px, py, size
          button:SetSize(size, size)
          button:ClearAllPoints()
          button:SetPoint("CENTER", UIParent, "BOTTOMLEFT", px, py)
          button:SetFrameStrata(anchor:GetFrameStrata())
          button:SetAttribute("spell", spell.name)
          button:Show()
        end
        ns.ApplyShape(button, ns.IsRound())
      elseif button and button:IsShown() then
        button:Hide()
      end
    end
    for index = #spells + 1, #selfButtons do
      if selfButtons[index]:IsShown() then
        selfButtons[index]:Hide()
      end
    end
  end
  SelfLooks()
end

-- /btrack debug
function ns.SelfDispelDebug()
  local shown, names = 0, {}
  for _, button in ipairs(selfButtons) do
    if button:IsShown() then
      shown = shown + 1
    end
  end
  for spell, list in pairs(selfRemovable) do
    for _, debuff in ipairs(list) do
      names[#names + 1] = debuff.name .. " (" .. debuff.type .. ", " .. spell.name .. ")"
    end
  end
  table.sort(names)
  return shown, names
end
