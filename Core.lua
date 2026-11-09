local _, ns = ...

ns.TITLE = "Tylesser - Buff Tracker"
ns.PREFIX = "|cffffd700Tylesser - Buff Tracker|r: "
ns.DEFAULT_ICON = 134400 -- question mark

ns.defaults = {
  locked = true,
  iconSize = 36,
}

ns.MIN_ICON_SIZE = 20
ns.MAX_ICON_SIZE = 64

-- When a tracked buff is shown. The first is the default for new buffs. "always" dims and marks
-- it red while it's missing.
ns.MODES = { "missing", "active", "always" }
ns.MODE_LABELS = { always = "Always", active = "When active", missing = "When missing" }

local MAX_BUFFS = 40

-- Current state per lowercase buff name: active, known, icon, count, expires.
-- known stays false until the game has let us read the buffs at least once.
ns.state = {}
-- The buffs read by the last scan, for the options page.
ns.buffs = {}
-- False while the game hides some or all buffs from addons.
ns.scanComplete = true

local function IsSecret(value)
  return issecretvalue and issecretvalue(value) or false
end

local function Plain(value)
  if IsSecret(value) then
    return nil
  end
  return value
end

local function GetBuff(unit, index)
  if C_UnitAuras and C_UnitAuras.GetBuffDataByIndex then
    return C_UnitAuras.GetBuffDataByIndex(unit, index)
  elseif C_UnitAuras and C_UnitAuras.GetAuraDataByIndex then
    return C_UnitAuras.GetAuraDataByIndex(unit, index, "HELPFUL")
  end
  local name, icon, count, _, duration, expirationTime = UnitAura(unit, index, "HELPFUL")
  if name then
    return { name = name, icon = icon, applications = count, duration = duration, expirationTime = expirationTime }
  end
end

-- Returns the unit's buffs the game lets us read, and whether that was all of them. Some clients
-- hide buffs from addons at times, such as in combat. Reading a hidden value raises an error, so
-- everything is checked first.
function ns.ReadBuffs(unit)
  local buffs = {}
  if C_Secrets and C_Secrets.ShouldAurasBeSecret and C_Secrets.ShouldAurasBeSecret() then
    return buffs, false
  end
  local complete = true
  for index = 1, MAX_BUFFS do
    if C_Secrets and C_Secrets.ShouldUnitAuraIndexBeSecret
      and C_Secrets.ShouldUnitAuraIndexBeSecret(unit, index, "HELPFUL") then
      complete = false
    else
      local aura = GetBuff(unit, index)
      if not aura then
        break
      end
      if IsSecret(aura) or (canaccesstable and not canaccesstable(aura)) or IsSecret(aura.name) then
        complete = false
      else
        buffs[#buffs + 1] = {
          name = aura.name,
          icon = Plain(aura.icon),
          count = Plain(aura.applications) or 0,
          expires = Plain(aura.expirationTime) or 0,
        }
      end
    end
  end
  return buffs, complete
end

-- Buffs are matched by name, so every rank of a spell counts. A buff that can't be read keeps
-- its last known state rather than showing up as missing.
function ns.Scan()
  local buffs, complete = ns.ReadBuffs("player")
  ns.buffs = buffs
  ns.scanComplete = complete

  local found = {}
  for _, buff in ipairs(buffs) do
    local key = buff.name:lower()
    if not found[key] then
      found[key] = buff
    end
  end

  for _, entry in ipairs(ns.db.tracked) do
    local key = entry.name:lower()
    local state = ns.state[key]
    if not state then
      state = {}
      ns.state[key] = state
    end
    local buff = found[key]
    if buff then
      state.known = true
      state.active = true
      state.count = buff.count
      state.expires = buff.expires
      -- Learn the exact name and icon, for buffs that were typed in by hand.
      entry.name = buff.name
      entry.icon = buff.icon or entry.icon
    elseif complete then
      state.known = true
      state.active = false
      state.count = 0
      state.expires = 0
    end
  end
end

function ns.StateOf(entry)
  return ns.state[entry.name:lower()]
end

-- Name and icon of a spell ID, or of a spell name the character knows.
local function SpellInfo(spell)
  if C_Spell and C_Spell.GetSpellInfo then
    local info = C_Spell.GetSpellInfo(spell)
    if info then
      return info.name, info.iconID
    end
  elseif GetSpellInfo then
    local name, _, icon = GetSpellInfo(spell)
    return name, icon
  end
end

local function FindTracked(name)
  local key = name:lower()
  for index, entry in ipairs(ns.db.tracked) do
    if entry.name:lower() == key then
      return index, entry
    end
  end
end

function ns.IsTracked(name)
  return FindTracked(name) ~= nil
end

-- Adds a buff by name or spell ID. icon is optional. Returns the entry, or nil and the reason.
function ns.AddBuff(input, icon)
  input = strtrim(tostring(input or ""))
  if input == "" then
    return nil, "type a buff name or spell ID."
  end
  local id = tonumber(input)
  local name, spellIcon = SpellInfo(id or input)
  if not name then
    if id then
      return nil, "no spell with the ID " .. input .. "."
    end
    name = input
  end
  if ns.IsTracked(name) then
    return nil, name .. " is already tracked."
  end
  local entry = { name = name, icon = icon or spellIcon, mode = ns.MODES[1] }
  table.insert(ns.db.tracked, entry)
  ns.Changed()
  return entry
end

function ns.RemoveBuff(name)
  local index = FindTracked(name)
  if not index then
    return false
  end
  table.remove(ns.db.tracked, index)
  ns.state[name:lower()] = nil
  ns.Changed()
  return true
end

function ns.CycleMode(entry)
  for index, mode in ipairs(ns.MODES) do
    if mode == entry.mode then
      entry.mode = ns.MODES[index % #ns.MODES + 1]
      break
    end
  end
  ns.Changed()
end

-- Call after anything that changes the tracked buffs.
function ns.Changed()
  ns.Scan()
  ns.UpdateDisplay()
  ns.RefreshOptions()
end

-- The character's active spells, one per name: { name, icon }, sorted by name.
function ns.GetSpellbook()
  local spells, seen = {}, {}
  local function Add(name, icon)
    if name and not seen[name] then
      seen[name] = true
      spells[#spells + 1] = { name = name, icon = icon }
    end
  end

  if C_SpellBook and C_SpellBook.GetNumSpellBookSkillLines and C_SpellBook.GetSpellBookItemInfo then
    local bank = Enum.SpellBookSpellBank.Player
    for line = 1, C_SpellBook.GetNumSpellBookSkillLines() do
      local info = C_SpellBook.GetSpellBookSkillLineInfo(line)
      if info then
        for slot = info.itemIndexOffset + 1, info.itemIndexOffset + info.numSpellBookItems do
          local item = C_SpellBook.GetSpellBookItemInfo(slot, bank)
          if item and item.itemType == Enum.SpellBookItemType.Spell and not item.isPassive then
            Add(item.name, item.iconID)
          end
        end
      end
    end
  elseif GetNumSpellTabs and GetSpellBookItemName then
    for tab = 1, GetNumSpellTabs() do
      local _, _, offset, count = GetSpellTabInfo(tab)
      for slot = offset + 1, offset + count do
        local isSpell = not GetSpellBookItemInfo or GetSpellBookItemInfo(slot, "spell") == "SPELL"
        if isSpell and not (IsPassiveSpell and IsPassiveSpell(slot, "spell")) then
          Add(GetSpellBookItemName(slot, "spell"), GetSpellBookItemTexture and GetSpellBookItemTexture(slot, "spell"))
        end
      end
    end
  end

  table.sort(spells, function(a, b)
    return a.name < b.name
  end)
  return spells
end
