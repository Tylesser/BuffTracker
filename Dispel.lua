local _, ns = ...
local L = ns.L

-- Dispels: a button for each debuff you can remove, next to party frames (Party.lua) and under
-- your own icon row (here). Click it to cast the dispel on that member, or on yourself.
-- Which debuffs you can remove follows the spells you know: a paladin with only Purify gets
-- buttons for Poison and Disease, and once they learn Cleanse also for Magic.
--
-- Combat: the game doesn't let addons show, hide or change clickable buttons in combat, yet that
-- is when dispels matter. So a debuff that shows up in combat gets a plain icon (no click) where
-- its button would go, for party and raid members in Party.lua ("Combat icons") and for you here.
-- Buttons made before combat keep working; changing their alpha and icon is allowed in combat.
-- When combat ends the icons go and the buttons are laid out again. Option dispel.combat.

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
-- The types as the player reads them (the English names above stay the game's keys).
local DEBUFF_TYPE_LABELS = { Magic = L["Magic"], Curse = L["Curse"], Disease = L["Disease"], Poison = L["Poison"],
  Bleed = L["Bleed"] }

function ns.DebuffColor(debuffType)
  return ns.DEBUFF_COLORS[debuffType] or OTHER_COLOR
end

local function ColoredType(debuffType)
  local color = ns.DebuffColor(debuffType)
  local function Byte(value)
    return math.floor(value * 255 + 0.5)
  end
  return string.format("|cff%02x%02x%02x%s|r", Byte(color[1]), Byte(color[2]), Byte(color[3]),
    DEBUFF_TYPE_LABELS[debuffType] or tostring(debuffType))
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

-- A debuff the game hides in a fight but says you can remove (ns.ReadDebuffs' { hidden = true }): its type is
-- unknown, so with one dispel it is that spell's (the button made before the fight lights up and works), and with
-- several it goes to ns.ANY_DISPEL, which only ever gets a plain combat icon (a click could cast the wrong spell).
ns.ANY_DISPEL = { name = "Dispel", any = true, types = {}, typeList = {} }

-- The spell whose range and mana the "any" icon shows: your first dispel.
function ns.DispelSpellFor(spell)
  if spell and spell.any then
    return ns.DispelSpells()[1] or spell
  end
  return spell
end

-- The icon for a debuff on a button or combat icon: its own, else (hidden in a fight) the dispel spell's.
function ns.DebuffIcon(spell, debuff)
  if debuff and debuff.icon then
    return debuff.icon
  end
  local name = ns.DispelSpellFor(spell)
  name = name and name.name
  local icon = name and ((C_Spell and C_Spell.GetSpellTexture and C_Spell.GetSpellTexture(name))
    or (GetSpellTexture and GetSpellTexture(name)))
  return icon or ns.DEFAULT_ICON
end

-- debuffs (from ns.ReadDebuffs with ns.DISPEL_FILTER) -> { [spell] = { debuff, ... } }: what each
-- of your dispels would remove. A type none of your spells lists gets no button.
function ns.RemovableDebuffs(debuffs)
  local bySpell = {}
  local spells = ns.DispelSpells()
  for _, debuff in ipairs(debuffs or {}) do
    local spell
    if debuff.hidden then
      spell = #spells == 1 and spells[1] or (#spells > 1 and ns.ANY_DISPEL) or nil
    else
      spell = SpellForType(debuff.type)
    end
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

-- Tooltip of a dispel button. who: "You" (yourself) or the member's name.
function ns.DispelTooltip(owner, spell, who, list)
  GameTooltip:SetOwner(owner, "ANCHOR_RIGHT")
  GameTooltip:AddLine(spell.name)
  local you = who == "You"
  if list and #list > 0 then
    for _, debuff in ipairs(list) do
      if debuff.hidden then
        GameTooltip:AddLine(you and L["You have a debuff you can remove (the game hides which in a fight)."]
          or L["%s has a debuff you can remove (the game hides which in a fight)."]:format(who), 1, 1, 1, true)
      elseif you then
        GameTooltip:AddLine(L["You have %s: %s"]:format(ColoredType(debuff.type), debuff.name), 1, 1, 1)
      else
        GameTooltip:AddLine(L["%s has %s: %s"]:format(who, ColoredType(debuff.type), debuff.name), 1, 1, 1)
      end
    end
    GameTooltip:AddLine(L["Click to remove it."], 0.6, 0.6, 0.6)
  else
    local types = {}
    for _, debuffType in ipairs(spell.typeList) do
      types[#types + 1] = ColoredType(debuffType)
    end
    GameTooltip:AddLine(L["Nothing to remove right now. Removes %s."]:format(table.concat(types, ", ")), 0.6, 0.6, 0.6,
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
  if dispel.combat == nil then
    dispel.combat = true
  end
end

-- Your own dispel buttons ------------------------------------------------------------------------
-- A row under the icon row, one button per dispel you know, placed by the row's anchor. They're
-- on UIParent, like the click overlays, so the icon row stays free to change in combat. In combat
-- a debuff without a button gets a plain icon (ns.NewDispelIcon) in the button's place.

local selfButtons = {}
local selfIcons = {} -- the plain icons for combat, made when first needed
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

-- Icon and colors of a button or combat icon for the first debuff it removes: allowed in combat.
local function DispelArt(frame, spell, list)
  local debuff = list[1]
  frame.icon:SetTexture(ns.DebuffIcon(spell, debuff))
  ns.SetFrameColor(frame, ns.DebuffColor(debuff.type))
  local _, noMana = IsUsable(ns.DispelSpellFor(spell).name)
  if noMana then
    frame.icon:SetVertexColor(0.4, 0.4, 1)
  else
    frame.icon:SetVertexColor(1, 1, 1)
  end
end

-- Alpha, icon and colors: allowed in combat.
local function SelfLooks()
  for _, button in ipairs(selfButtons) do
    if button:IsShown() and button.spell then
      local list = selfRemovable[button.spell]
      if list then
        DispelArt(button, button.spell, list)
        button:SetAlpha(1)
      else
        button:SetAlpha(0) -- in combat, when it can't be hidden
      end
    end
  end
end

local function GetSelfIcon(index)
  local icon = selfIcons[index]
  if not icon then
    icon = ns.NewDispelIcon()
    selfIcons[index] = icon
  end
  return icon
end

-- Hides every combat icon, or those past the first `used`.
local function HideSelfIcons(used)
  for index = (used or 0) + 1, #selfIcons do
    if selfIcons[index]:IsShown() then
      selfIcons[index]:Hide()
    end
  end
end

-- Places a button or combat icon at the spot of the index-th dispel under the row anchor.
local function PlaceSelf(frame, anchor, px, py, size)
  frame:SetSize(size, size)
  frame:ClearAllPoints()
  frame:SetPoint("CENTER", UIParent, "BOTTOMLEFT", px, py)
  frame:SetFrameStrata(anchor:GetFrameStrata())
end

function ns.UpdateSelfDispel()
  if not ns.db then
    return
  end
  local spells = ns.DispelSpells()
  selfRemovable = (ns.db.dispel.self and #spells > 0)
    and ns.RemovableDebuffs(ns.ReadDebuffs("player", ns.DISPEL_FILTER)) or {}
  local anchor = ns.RowAnchor and ns.RowAnchor()
  local x, y
  if anchor and ns.db.dispel.self and not ns.IsRowUnlocked() then
    x, y = anchor:GetCenter()
  end
  local size = ns.db.iconSize
  local function Spot(index)
    return x + (index - (#spells + 1) / 2) * (size + GAP), y - size - BELOW_ROW
  end
  if InCombatLockdown() then
    -- plain icons where the buttons would be, for the debuffs no button made before combat shows
    local used = 0
    if x and ns.db.dispel.combat then
      for index, spell in ipairs(spells) do
        local button = selfButtons[index]
        local covered = button and button:IsShown() and button.spell == spell
        local list = selfRemovable[spell]
        if list and not covered then
          used = used + 1
          local icon = GetSelfIcon(used)
          icon.spell = spell
          local px, py = Spot(index)
          if not (icon:IsShown() and icon.px == px and icon.py == py and icon.size == size) then
            icon.px, icon.py, icon.size = px, py, size
            PlaceSelf(icon, anchor, px, py, size)
            icon:Show()
          end
          ns.ApplyShape(icon, ns.IsRound())
          DispelArt(icon, spell, list)
          icon.count:SetText(#list > 1 and tostring(#list) or "")
        end
      end
      -- debuffs hidden in the fight that one of several dispels removes: one icon after the others
      local hidden = selfRemovable[ns.ANY_DISPEL]
      if hidden then
        used = used + 1
        local icon = GetSelfIcon(used)
        icon.spell = ns.ANY_DISPEL
        local px, py = Spot(#spells + 1)
        if not (icon:IsShown() and icon.px == px and icon.py == py and icon.size == size) then
          icon.px, icon.py, icon.size = px, py, size
          PlaceSelf(icon, anchor, px, py, size)
          icon:Show()
        end
        ns.ApplyShape(icon, ns.IsRound())
        DispelArt(icon, ns.ANY_DISPEL, hidden)
        icon.count:SetText(#hidden > 1 and tostring(#hidden) or "")
      end
    end
    HideSelfIcons(used)
  else
    HideSelfIcons()
    for index, spell in ipairs(spells) do
      local wanted = x and selfRemovable[spell]
      local button = wanted and GetSelfButton(index) or selfButtons[index]
      if wanted then
        local px, py = Spot(index)
        if not (button:IsShown() and button.spell == spell and button.px == px and button.py == py
          and button.size == size) then
          button.spell, button.px, button.py, button.size = spell, px, py, size
          PlaceSelf(button, anchor, px, py, size)
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
  for _, icon in ipairs(selfIcons) do
    if icon:IsShown() then
      shown = shown + 1
    end
  end
  for spell, list in pairs(selfRemovable) do
    for _, debuff in ipairs(list) do
      names[#names + 1] = (debuff.name or "hidden") .. " (" .. (debuff.type or "?") .. ", " .. spell.name .. ")"
    end
  end
  table.sort(names)
  return shown, names
end
