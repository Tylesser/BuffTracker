local _, ns = ...

ns.TITLE = "Tylesser - Buff Tracker"
ns.PREFIX = ns.T.Prefix("Buff Tracker")
ns.DEFAULT_ICON = 134400 -- question mark

ns.defaults = {
  locked = true,
  iconSize = 36,
  clickToCast = true,
  iconShape = "square",
}

-- Icon shapes, in the order the options button cycles through them.
ns.SHAPES = { "square", "circle" }
ns.SHAPE_LABELS = { square = "Square", circle = "Circle" }

ns.MIN_ICON_SIZE = 20
ns.MAX_ICON_SIZE = 64

-- When a tracked buff is shown. The first is the default for new buffs. "always" dims and marks
-- it red while it's missing.
ns.MODES = { "missing", "active", "always" }
ns.MODE_LABELS = { always = "Always", active = "When active", missing = "When missing" }

local MAX_BUFFS = 40

-- A tracked entry: { name, icon, mode }, plus, all optional: item (item ID used by a click),
-- alert (sound and flash when it drops in combat), slot (16 or 17: a weapon enchant, not a buff).

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
  local name, icon, count, _, duration, expirationTime, source = UnitAura(unit, index, "HELPFUL")
  if name then
    return { name = name, icon = icon, applications = count, duration = duration, expirationTime = expirationTime,
      sourceUnit = source }
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
        -- mine: true when you cast it, false when someone else did, nil when the game doesn't say
        local source, fromPlayer = Plain(aura.sourceUnit), Plain(aura.isFromPlayerOrPlayerPet)
        local mine
        if type(source) == "string" then
          mine = source == "player"
        elseif type(fromPlayer) == "boolean" then
          mine = fromPlayer
        end
        buffs[#buffs + 1] = {
          name = aura.name,
          icon = Plain(aura.icon),
          count = Plain(aura.applications) or 0,
          expires = Plain(aura.expirationTime) or 0,
          mine = mine,
        }
      end
    end
  end
  return buffs, complete
end

local function GetDebuff(unit, index, filter)
  if C_UnitAuras and C_UnitAuras.GetAuraDataByIndex then
    return C_UnitAuras.GetAuraDataByIndex(unit, index, filter)
  end
  local name, icon, count, debuffType, _, expirationTime = UnitAura(unit, index, filter)
  if name then
    return { name = name, icon = icon, applications = count, dispelName = debuffType, expirationTime = expirationTime }
  end
end

-- The unit's debuffs that have a type (Magic, Curse, Disease, Poison): { name, icon, type, count,
-- expires }. filter is "HARMFUL", or "HARMFUL|RAID" for only those the game says you can remove.
-- Debuffs the game hides are left out, with the same checks as ReadBuffs.
function ns.ReadDebuffs(unit, filter)
  local debuffs = {}
  if C_Secrets and C_Secrets.ShouldAurasBeSecret and C_Secrets.ShouldAurasBeSecret() then
    return debuffs
  end
  for index = 1, MAX_BUFFS do
    local hidden = false
    if C_Secrets and C_Secrets.ShouldUnitAuraIndexBeSecret then
      -- pcall: only "HELPFUL" is known to work here; the values themselves are checked below anyway
      local ok, secret = pcall(C_Secrets.ShouldUnitAuraIndexBeSecret, unit, index, filter)
      hidden = ok and secret or false
    end
    if not hidden then
      local aura = GetDebuff(unit, index, filter)
      if not aura then
        break
      end
      if not (IsSecret(aura) or (canaccesstable and not canaccesstable(aura)) or IsSecret(aura.name)) then
        local debuffType = Plain(aura.dispelName)
        if type(debuffType) == "string" and debuffType ~= "" then
          debuffs[#debuffs + 1] = {
            name = aura.name,
            icon = Plain(aura.icon),
            type = debuffType,
            count = Plain(aura.applications) or 0,
            expires = Plain(aura.expirationTime) or 0,
          }
        end
      end
    end
  end
  return debuffs
end

-- Alerts ----------------------------------------------------------------------------------------
-- A tracked buff with "Alert" on that drops while you're in combat plays the raid warning sound
-- and flashes its icon. Display.lua flashes the icons named in ns.pendingFlash.

ns.pendingFlash = {}
local ALERT_SOUND_SECONDS = 1 -- several buffs dropping at once (a dispel) play the sound once
local lastAlertSound = -math.huge

function ns.BuffDropped(entry)
  if not (entry and entry.alert and InCombatLockdown()) then
    return
  end
  ns.pendingFlash[entry.name:lower()] = true
  local now = GetTime()
  if PlaySound and now - lastAlertSound >= ALERT_SOUND_SECONDS then
    lastAlertSound = now
    pcall(PlaySound, (SOUNDKIT and SOUNDKIT.RAID_WARNING) or 8959, "Master")
  end
end

-- Weapon enchants (oils, poisons, sharpening stones): tracked like buffs, read with
-- GetWeaponEnchantInfo. 16 = main hand, 17 = off hand.
ns.WEAPON_SLOTS = { 16, 17 }
ns.WEAPON_NAMES = { [16] = "Main-hand weapon enchant", [17] = "Off-hand weapon enchant" }

-- { [16] = { active, expires, count }, [17] = ... }, or nil when the game doesn't tell.
local function ReadWeapons()
  if not GetWeaponEnchantInfo then
    return nil
  end
  local values = { pcall(GetWeaponEnchantInfo) }
  if not values[1] then
    return nil
  end
  for index = 2, 9 do
    if IsSecret(values[index]) then
      return nil
    end
  end
  local now = GetTime()
  local function Slot(has, ms, charges)
    local active = (has and has ~= 0) and true or false
    return {
      active = active,
      expires = (active and type(ms) == "number" and ms > 0) and now + ms / 1000 or 0,
      count = (active and type(charges) == "number") and charges or 0,
    }
  end
  return { [16] = Slot(values[2], values[3], values[4]), [17] = Slot(values[6], values[7], values[8]) }
end

local function StateFor(entry)
  local key = entry.name:lower()
  local state = ns.state[key]
  if not state then
    state = {}
    ns.state[key] = state
  end
  return state
end

local function SetState(entry, state, active, count, expires)
  if state.known and state.active and not active then
    ns.BuffDropped(entry)
  end
  state.known = true
  state.active = active
  state.count = count
  state.expires = expires
end

-- Reads the weapon enchants of tracked weapon entries. Returns whether one came or went, or its
-- charges changed (the timer alone doesn't count).
function ns.ScanWeapons()
  local weapons
  local changed = false
  for _, entry in ipairs(ns.db.tracked) do
    if entry.slot then
      weapons = weapons or ReadWeapons() or false
      local weapon = weapons and weapons[entry.slot]
      if weapon then
        local state = StateFor(entry)
        changed = changed or state.active ~= weapon.active or state.count ~= weapon.count or not state.known
        SetState(entry, state, weapon.active, weapon.count, weapon.expires)
      end
    end
  end
  return changed
end

function ns.HasWeaponEntries()
  for _, entry in ipairs(ns.db.tracked) do
    if entry.slot then
      return true
    end
  end
  return false
end

-- Buffs are matched by name, so every rank of a spell counts. A buff that can't be read keeps
-- its last known state rather than showing up as missing.
-- Minimap tracking (Find Minerals, Find Herbs, Track Beasts, ...): on Forever these are not auras, so the
-- active ones are read from the tracking list and count as buffs that are up (no timer).
local function TrackingInfo(index)
  local a, b, c, d, e, f = C_Minimap.GetTrackingInfo(index)
  if type(a) == "table" then
    return a.name, a.texture, a.active
  end
  return a, b, c -- older form: name, texture, active, ...
end

function ns.ReadTracking()
  local list = {}
  local ok, count = false, 0
  if C_Minimap and C_Minimap.GetNumTrackingTypes and C_Minimap.GetTrackingInfo then
    ok, count = pcall(C_Minimap.GetNumTrackingTypes)
  end
  for index = 1, (ok and type(count) == "number") and count or 0 do
    local okInfo, name, texture, active = pcall(TrackingInfo, index)
    if okInfo and active and type(name) == "string" and name ~= "" then
      list[#list + 1] = { name = name, icon = texture, count = 0, expires = 0, mine = true }
    end
  end
  -- the older single-tracking call: the icon of the one tracking that is on (matched by icon below)
  if type(GetTrackingTexture) == "function" then
    local ok, texture = pcall(GetTrackingTexture)
    if ok and texture ~= nil and (not canaccessvalue or canaccessvalue(texture)) then
      list[#list + 1] = { icon = texture, count = 0, expires = 0, mine = true }
    end
  end
  return list
end

-- One chat-ready line about what the game reports as tracking (for /btrack debug and /codex buffs debug).
function ns.TrackingDebug()
  local parts = {}
  if C_Minimap and C_Minimap.GetNumTrackingTypes then
    local ok, count = pcall(C_Minimap.GetNumTrackingTypes)
    parts[#parts + 1] = "types=" .. tostring(count)
    for index = 1, (ok and type(count) == "number") and math.min(count, 12) or 0 do
      local okInfo, name, texture, active = pcall(TrackingInfo, index)
      if okInfo and name then
        parts[#parts + 1] = ("%s%s(%s)"):format(active and "*" or "", tostring(name), tostring(texture))
      end
    end
  else
    parts[#parts + 1] = "no C_Minimap tracking"
  end
  if type(GetTrackingTexture) == "function" then
    local ok, texture = pcall(GetTrackingTexture)
    parts[#parts + 1] = "GetTrackingTexture=" .. tostring(ok and texture)
  end
  return table.concat(parts, " ")
end

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
  local trackingIcons = {}
  for _, tracking in ipairs(ns.ReadTracking()) do
    if tracking.name then
      local key = tracking.name:lower()
      if not found[key] then
        found[key] = tracking
      end
    end
    if tracking.icon then
      trackingIcons[tracking.icon] = tracking
    end
  end

  for _, entry in ipairs(ns.db.tracked) do
    if not entry.slot then
      local state = StateFor(entry)
      -- by name, else an active tracking with the entry's icon (Forever may name tracking differently)
      local buff = found[entry.name:lower()] or (entry.icon and trackingIcons[entry.icon])
      if buff then
        SetState(entry, state, true, buff.count, buff.expires)
        -- Learn the exact name and icon, for buffs that were typed in by hand.
        entry.name = buff.name or entry.name -- a tracking matched by icon has no name
        entry.icon = buff.icon or entry.icon
      elseif complete then
        SetState(entry, state, false, 0, 0)
      end
    end
  end
  ns.ScanWeapons()
end

function ns.StateOf(entry)
  return ns.state[entry.name:lower()]
end

-- Items ------------------------------------------------------------------------------------------
-- A tracked buff can be given by an item: one attached in the options (entry.item, an item ID), or
-- else, when you don't know the buff's spell, a bag item whose use spell has the buff's name
-- (elixirs, scrolls). Clicking the icon uses that item.

local function GetCount(id)
  local get = (C_Item and C_Item.GetItemCount) or GetItemCount
  return get and get(id) or 0
end
ns.ItemCount = GetCount

function ns.ItemName(id)
  local name
  if C_Item and C_Item.GetItemNameByID then
    name = C_Item.GetItemNameByID(id)
  elseif GetItemInfo then
    name = GetItemInfo(id)
  end
  return name
end

function ns.ItemIcon(id)
  if C_Item and C_Item.GetItemIconByID then
    return C_Item.GetItemIconByID(id)
  elseif GetItemIcon then
    return GetItemIcon(id)
  end
end

local function ItemSpellName(id)
  local get = (C_Item and C_Item.GetItemSpell) or GetItemSpell
  if not get then
    return nil
  end
  local ok, name = pcall(get, id)
  return ok and type(name) == "string" and name or nil
end

local function ContainerItemID(bag, slot)
  if C_Container and C_Container.GetContainerItemID then
    return C_Container.GetContainerItemID(bag, slot)
  elseif GetContainerItemID then
    return GetContainerItemID(bag, slot)
  end
end

local function ContainerSlots(bag)
  if C_Container and C_Container.GetContainerNumSlots then
    return C_Container.GetContainerNumSlots(bag)
  elseif GetContainerNumSlots then
    return GetContainerNumSlots(bag)
  end
  return 0
end

-- Items you wear (trinkets with a use): a secure "item" click would equip them, so they're left out.
function ns.IsEquippable(id)
  local check = (C_Item and C_Item.IsEquippableItem) or IsEquippableItem
  if not check then
    return false
  end
  local ok, equippable = pcall(check, id)
  return ok and equippable and true or false
end

local bagItems     -- usable bag items, one per item ID: { id, name, spell }, sorted by name
local pendingItems = {} -- item IDs in the bags the game hasn't sent the name of yet

-- Reads the bags again. Called when they change.
function ns.ScanBags()
  local list, seen = {}, {}
  pendingItems = {}
  for bag = 0, NUM_TOTAL_EQUIPPED_BAG_SLOTS or NUM_BAG_SLOTS or 4 do
    for slot = 1, ContainerSlots(bag) or 0 do
      local id = ContainerItemID(bag, slot)
      if id and not seen[id] then
        seen[id] = true
        local name = ns.ItemName(id)
        if not name then
          pendingItems[id] = true
        end
        local spell = ItemSpellName(id)
        if spell and not ns.IsEquippable(id) then
          list[#list + 1] = { id = id, name = name, spell = spell }
        end
      end
    end
  end
  table.sort(list, function(a, b)
    return (a.name or "") < (b.name or "")
  end)
  bagItems = list
end

-- Whether a bag item's details were still missing at the last scan (GET_ITEM_INFO_RECEIVED).
function ns.ItemPending(id)
  return pendingItems[id] or false
end

function ns.BagItems()
  if not bagItems then
    ns.ScanBags()
  end
  return bagItems
end

local function BagItemForBuff(name)
  local key = name:lower()
  for _, item in ipairs(ns.BagItems()) do
    if item.spell:lower() == key then
      return item.id
    end
  end
end

-- The item to use for an entry, and whether it was found automatically (not attached).
function ns.ItemFor(entry)
  if entry.item then
    return entry.item, false
  end
  if entry.slot or ns.KnowsSpell(entry.name) then
    return nil
  end
  local id = BagItemForBuff(entry.name)
  return id, id ~= nil
end

-- What a click on the entry's icon does: { item = id, slot = 16/17 or nil }, { spell = name }, or
-- nil (nothing to click: no known spell, or the item is gone).
function ns.ClickAction(entry)
  local id = ns.ItemFor(entry)
  if id and GetCount(id) > 0 then
    return { item = id, slot = entry.slot }
  end
  if not entry.slot and ns.KnowsSpell(entry.name) then
    return { spell = entry.name }
  end
end

-- Attaches an item to the entry (nil: none, back to the automatic choice).
function ns.SetItem(entry, id)
  entry.item = id
  ns.Changed()
end

-- Next usable bag item for the entry's "Use item" button: none, then each item in turn.
function ns.CycleItem(entry)
  local items = ns.BagItems()
  local nextID = items[1] and items[1].id
  for index, item in ipairs(items) do
    if item.id == entry.item then
      nextID = items[index + 1] and items[index + 1].id
      break
    end
  end
  ns.SetItem(entry, nextID)
end

-- An item ID from a typed ID, an item link, or the name of an item in the bags or the game's cache.
function ns.ResolveItem(text)
  text = strtrim(tostring(text or ""))
  if text == "" then
    return nil
  end
  local id = tonumber(text) or tonumber(text:match("item:(%d+)"))
  if id then
    return id
  end
  local key = text:lower()
  for _, item in ipairs(ns.BagItems()) do
    if item.name and item.name:lower() == key then
      return item.id
    end
  end
  local instant = (C_Item and C_Item.GetItemInfoInstant) or GetItemInfoInstant
  if instant then
    local ok, found = pcall(instant, text)
    if ok and type(found) == "number" then
      return found
    end
  end
end

-- Icon for an entry: the buff's own, the weapon's for weapon enchants, else the attached item's.
function ns.EntryIcon(entry)
  if entry.icon then
    return entry.icon
  end
  if entry.slot and GetInventoryItemTexture then
    local texture = GetInventoryItemTexture("player", entry.slot)
    if texture then
      return texture
    end
  end
  return entry.item and ns.ItemIcon(entry.item) or ns.DEFAULT_ICON
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

-- The tracked entry with this name (any capitals), or nil.
function ns.FindTracked(name)
  local _, entry = FindTracked(name)
  return entry
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

-- Tracks the enchant on a weapon slot (16 main hand, 17 off hand).
function ns.AddWeapon(slot)
  local name = ns.WEAPON_NAMES[slot]
  if not name or ns.IsTracked(name) then
    return nil
  end
  local entry = { name = name, slot = slot, mode = ns.MODES[1] }
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

-- Class basics ---------------------------------------------------------------------------------
-- "Add <class> basics" on the options page. A list inside the list is a set of buffs that replace
-- each other (armors, shields, aspects): the first one known is added, best first, and none when
-- one of them is tracked already. "blessing" is the paladin's own blessing, chosen like the party
-- buttons choose one for paladins (the Party buffs page), Wisdom unless changed there.
ns.PRESETS = {
  MAGE = { "Arcane Intellect", { "Molten Armor", "Mage Armor", "Ice Armor", "Frost Armor" } },
  PRIEST = { "Power Word: Fortitude", "Inner Fire", "Divine Spirit" },
  DRUID = { "Mark of the Wild", "Thorns" },
  WARLOCK = { { "Fel Armor", "Demon Armor", "Demon Skin" } },
  WARRIOR = { "Battle Shout" },
  HUNTER = { "Trueshot Aura", { "Aspect of the Dragonhawk", "Aspect of the Hawk" } },
  SHAMAN = { { "Water Shield", "Lightning Shield" } },
  PALADIN = { "Devotion Aura", "blessing" },
  DEATHKNIGHT = { "Horn of Winter" },
}

local function BlessingChoices()
  local list = {}
  local chosen = ns.FAMILY[ns.BlessingFor("player") or ""]
  if chosen then
    list[#list + 1] = chosen.spells[#chosen.spells].name
  end
  list[#list + 1] = "Blessing of Wisdom"
  list[#list + 1] = "Blessing of Might"
  return list
end

-- The basics of your class you know and don't track yet, and your class (nil: no basics for it).
function ns.PresetBuffs()
  local _, class = UnitClass("player")
  local preset = class and ns.PRESETS[class]
  if not preset then
    return nil, class
  end
  local list = {}
  for _, item in ipairs(preset) do
    local choices = item
    if item == "blessing" then
      choices = BlessingChoices()
    elseif type(item) == "string" then
      choices = { item }
    end
    local tracked = false
    for _, name in ipairs(choices) do
      tracked = tracked or ns.IsTracked(name)
    end
    if not tracked then
      for _, name in ipairs(choices) do
        if ns.KnowsSpell(name) then
          list[#list + 1] = name
          break
        end
      end
    end
  end
  return list, class
end

function ns.AddPreset()
  local list = ns.PresetBuffs()
  if not list then
    print(ns.PREFIX .. "there are no basics for your class yet.")
    return
  end
  if #list == 0 then
    print(ns.PREFIX .. "nothing to add: you already track the basic buffs you know.")
    return
  end
  local added = {}
  for _, name in ipairs(list) do
    local entry = ns.AddBuff(name)
    if entry then
      added[#added + 1] = entry.name
    end
  end
  print(ns.PREFIX .. "added " .. table.concat(added, ", ") .. ".")
end
