local _, ns = ...

-- Buttons next to the party frames (in a raid: small, in a corner of the raid frames) for group
-- buffs a member is missing. Clicking one casts the buff on that member. They are secure buttons:
-- the game doesn't let addons show, hide, move or change them in combat, so all of that happens
-- out of combat. In combat party buttons keep working as they were, and a buff that lands on the
-- member only dims its button. Raid buttons sit on a secure holder that the game itself hides in
-- combat (a state driver), so they never catch a click meant for healing. Buttons are made only
-- when first needed (out of combat), as each one costs memory.

local SIZE = 24
local RAID_MIN_SIZE, RAID_MAX_SIZE = 12, 14 -- buttons in a raid frame's corner
local RAID_WIDTH_SHARE = 1 / 3 -- they take at most about this much of the raid frame's width
local GAP = 2
local MAX_PER_UNIT = 8 -- group buffs and, with "every blessing", up to six blessings
local REFRESH_SECONDS = 1
local RAID_DIRTY_SECONDS = 0.5 -- in a raid, events come often: lay out at most this often
local RAID_FULL_SCAN_SECONDS = 5 -- in a raid, buffs are read on UNIT_AURA, and all of them this often
local PARTY_UNITS = { "player", "party1", "party2", "party3", "party4" }
local RAID_UNITS = {}
for i = 1, 40 do
  RAID_UNITS[i] = "raid" .. i
end
local NO_MANA = { WARRIOR = true, ROGUE = true, DEATHKNIGHT = true, DEMONHUNTER = true }
-- How often to look through all frames for a member whose frame wasn't found. Each search that
-- finds nothing doubles the wait, up to the maximum; group changes start again at the minimum.
local SEARCH_SECONDS, SEARCH_MAX_SECONDS = 3, 60

-- "Also show buffs that end within": the choices, in seconds. The first one larger than the
-- current value is next when the button is clicked.
ns.REFRESH_CHOICES = { 10, 30, 60, 120, 300 }
ns.DEFAULT_REFRESH_SECONDS = 60

function ns.FormatSeconds(seconds)
  if seconds >= 60 and seconds % 60 == 0 then
    return string.format("%d min", seconds / 60)
  end
  return seconds .. " sec"
end

-- "Hide when farther than": the choices, in yards.
ns.RANGE_CHOICES = { 30, 40, 60, 80, 100 }
ns.DEFAULT_RANGE_YARDS = 60
-- "Warn when reagents drop to": the choices; 0 is off.
ns.REAGENT_CHOICES = { 0, 1, 3, 5, 10, 20 }
ns.DEFAULT_REAGENT_WARN = 5

local SIGHT_YARDS = 100 -- about how far the game shows other players: farther, UnitIsVisible is false
local UNIT_IN_RANGE_YARDS = 40 -- about what UnitInRange checks

-- Yards between you and the unit, or nil when the game doesn't tell (in instances, on another
-- map, or when positions are hidden from addons).
-- Run with pcall: positions can be hidden from addons (secret values), and comparing or adding
-- those raises an error.
local function DistanceOrError(unit)
  local y1, x1, _, map1 = UnitPosition("player")
  local y2, x2, _, map2 = UnitPosition(unit)
  if not (y1 and y2) or map1 ~= map2 then
    return nil
  end
  return math.sqrt((x2 - x1) ^ 2 + (y2 - y1) ^ 2)
end

local function Distance(unit)
  if not UnitPosition then
    return nil
  end
  local ok, distance = pcall(DistanceOrError, unit)
  return ok and distance or nil
end

-- Without a position: whether UnitIsVisible or UnitInRange prove the unit is past the limit.
local function FarBySight(unit, limit)
  if limit <= SIGHT_YARDS and UnitIsVisible and not UnitIsVisible(unit) then
    return true
  end
  if limit <= UNIT_IN_RANGE_YARDS and UnitInRange then
    local inRange, checked = UnitInRange(unit)
    return checked and not inRange
  end
  return false
end

-- Whether the unit is past the distance limit. Without a position the game only tells whether
-- they're out of sight (about 100 yards) or out of UnitInRange (about 40 yards), so a member is
-- hidden only when one of those proves they're too far.
local function TooFar(unit)
  local party = ns.db.party
  if not party.range or UnitIsUnit(unit, "player") then
    return false
  end
  local limit = party.rangeYards
  local distance = Distance(unit)
  if distance then
    return distance > limit
  end
  local ok, far = pcall(FarBySight, unit, limit)
  return ok and far or false
end

-- Seconds left below which a buff counts as ending soon; nil when that option is off.
local function RefreshSeconds()
  local party = ns.db.party
  return party.refresh and party.refreshSeconds or nil
end

local function EndsSoon(remaining)
  local seconds = RefreshSeconds()
  return seconds ~= nil and remaining < seconds
end

-- Reagent item IDs differ per game version (interface number from GetBuildInfo). Classic Era and
-- WoW Forever: Arcane Powder, Sacred/Holy Candle, Wild Thornroot/Berries, Symbol of Kings. TBC: Gift
-- of the Wild takes Wild Quillvine. Wrath: Wild Spineleaf, and Devout Candle for the Prayers. MoP
-- and later: these spells take no reagents.
local INTERFACE = select(4, GetBuildInfo()) or 0
local REAGENTS = {
  powder = { 17020 }, candles = { 17029, 17028 }, sacred = { 17029 }, wild = { 17026, 17021 }, symbol = { 21177 },
}
if INTERFACE >= 50000 then
  REAGENTS = {}
elseif INTERFACE >= 30000 then
  REAGENTS.candles, REAGENTS.sacred, REAGENTS.wild = { 44615 }, { 44615 }, { 44605 }
elseif INTERFACE >= 20000 then
  REAGENTS.wild = { 22148 }
end

-- Buffs you can give your group. The first spell is preferred; when it can't be cast (usually a
-- missing reagent) the next one is used. Any of the spells counts as having the buff.
-- English spell names; reagent item IDs are only for the tooltip and the low reagent warning.
ns.GROUP_BUFFS = {
  { key = "intellect", manaOnly = true, spells = {
    { name = "Arcane Brilliance", reagents = REAGENTS.powder }, { name = "Arcane Intellect" } } },
  { key = "fortitude", spells = {
    { name = "Prayer of Fortitude", reagents = REAGENTS.candles }, { name = "Power Word: Fortitude" } } },
  { key = "spirit", manaOnly = true, spells = {
    { name = "Prayer of Spirit", reagents = REAGENTS.sacred }, { name = "Divine Spirit" } } },
  { key = "shadow", spells = {
    { name = "Prayer of Shadow Protection", reagents = REAGENTS.sacred }, { name = "Shadow Protection" } } },
  { key = "wild", spells = {
    { name = "Gift of the Wild", reagents = REAGENTS.wild }, { name = "Mark of the Wild" } } },
}

-- Paladin blessings: one per member, chosen by class or per member in the options.
ns.BLESSINGS = {}
for _, blessing in ipairs({ "Might", "Wisdom", "Kings", "Salvation", "Light", "Sanctuary" }) do
  table.insert(ns.BLESSINGS, { key = blessing:lower(), label = blessing, blessing = true, spells = {
    { name = "Greater Blessing of " .. blessing, reagents = REAGENTS.symbol }, { name = "Blessing of " .. blessing } } })
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

local function IsUsable(name)
  if C_Spell and C_Spell.IsSpellUsable then
    return C_Spell.IsSpellUsable(name)
  end
  return IsUsableSpell(name)
end

local function ItemCount(id)
  local GetCount = (C_Item and C_Item.GetItemCount) or GetItemCount
  return GetCount(id) or 0
end

local function ItemName(id)
  if C_Item and C_Item.GetItemNameByID then
    return C_Item.GetItemNameByID(id)
  end
  return (GetItemInfo(id))
end

function ns.ReagentCount(spell)
  local count = 0
  for _, id in ipairs(spell.reagents or {}) do
    count = count + ItemCount(id)
  end
  return count
end

function ns.ReagentName(spell)
  local id = spell.reagents and spell.reagents[1]
  return id and ItemName(id) or nil
end

-- Whether none is left, yet the game says the spell can be cast: then our item IDs are wrong for
-- this client (or the spell needs no reagent here), and nothing should be flagged.
local function CastsWithout(spell, count)
  return count == 0 and IsUsable(spell.name) and true or false
end

-- Whether the spell's reagent count is at or below the warning level (off: never).
function ns.ReagentLow(spell)
  local limit = ns.db.party.reagentWarn or 0
  if not spell.reagents or limit <= 0 then
    return false
  end
  local count = ns.ReagentCount(spell)
  return count <= limit and not CastsWithout(spell, count)
end

-- Low reagent warning: one chat line each time a reagent you use drops to a new lower count at or
-- below the limit. The first count seen is only remembered, so logging in with few doesn't warn.
-- Watched per item ID, so a candle used by three Prayers is one line.
local reagentSeen = {} -- item ID -> last count

local function WatchedReagents()
  local list, byID = {}, {}
  local function Watch(families)
    for _, family in ipairs(families) do
      for _, spell in ipairs(family.spells) do
        if spell.reagents and ns.FamilyEnabled(family) and ns.KnowsSpell(spell.name) then
          for _, id in ipairs(spell.reagents) do
            local watched = byID[id]
            if not watched then
              watched = { id = id, spells = {} }
              byID[id] = watched
              list[#list + 1] = watched
            end
            watched.spells[#watched.spells + 1] = spell
          end
        end
      end
    end
  end
  Watch(ns.GROUP_BUFFS)
  Watch(ns.BLESSINGS)
  return list
end

function ns.CheckReagents()
  local limit = ns.db.party.reagentWarn or 0
  for _, watched in ipairs(WatchedReagents()) do
    local count = ItemCount(watched.id)
    local last = reagentSeen[watched.id]
    if last and count < last and limit > 0 and count <= limit then
      local castsAnyway = false
      for _, spell in ipairs(watched.spells) do
        castsAnyway = castsAnyway or CastsWithout(spell, count)
      end
      if not castsAnyway then
        print(ns.PREFIX .. count .. " " .. (ItemName(watched.id) or ("item " .. watched.id)) .. " left.")
      end
    end
    reagentSeen[watched.id] = count
  end
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
-- The same buffs that may be yours: cast by you, or the game doesn't say who cast them.
local fromMe = {}

local function ScanUnit(unit)
  local buffs, complete = ns.ReadBuffs(unit)
  if not complete and auras[unit] then
    return -- hidden right now: keep what we knew
  end
  local found, mine = {}, {}
  for _, buff in ipairs(buffs) do
    found[buff.name:lower()] = buff.expires
    if buff.mine ~= false then
      mine[buff.name:lower()] = true
    end
  end
  auras[unit] = complete and found or nil
  fromMe[unit] = complete and mine or nil
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

-- Whether the unit has a blessing from you. A blessing whose caster the game doesn't give counts
-- as yours, so "every blessing" never shows by mistake right after you bless someone.
local function HasMyBlessing(unit)
  local mine = fromMe[unit]
  if not mine then
    return false
  end
  for _, family in ipairs(ns.BLESSINGS) do
    for _, spell in ipairs(family.spells) do
      if mine[spell.name:lower()] then
        return true
      end
    end
  end
  return false
end

local function HasAnyBlessing(unit)
  for _, family in ipairs(ns.BLESSINGS) do
    if Remaining(unit, family) then
      return true
    end
  end
  return false
end

-- The blessings to offer the unit: the chosen one, or with "every blessing" on, each known
-- blessing they're missing when they have none at all or another paladin gave them the chosen
-- one. extra[family] marks the blessings shown only because of that. With it on, a blessing
-- from you counts as done even when it isn't the chosen one.
local function BlessingsFor(unit)
  local chosen = ns.FAMILY[ns.BlessingFor(unit) or ""]
  if not (chosen and ns.KnowsFamily(chosen)) then
    return {}, {} -- "None", or a blessing you don't know
  end
  if not ns.db.party.allBlessings then
    return { chosen }, {}
  end
  if HasMyBlessing(unit) then
    -- any blessing from you will do, as you can keep only one on each member; the chosen one
    -- stays in the list so it can still be refreshed when it ends soon
    return Remaining(unit, chosen) and { chosen } or {}, {}
  end
  local chosenTaken = Remaining(unit, chosen) ~= nil
  if not chosenTaken and HasAnyBlessing(unit) then
    return { chosen }, {}
  end
  local list, extra = {}, {}
  if not chosenTaken then
    list[1] = chosen
  end
  for _, family in ipairs(ns.KnownBlessings()) do
    if family ~= chosen and Remaining(unit, family) == nil then
      list[#list + 1] = family
      extra[family] = true
    end
  end
  return list, extra
end

-- The buff families to offer the unit, and which blessings are extras (see BlessingsFor).
local function FamiliesFor(unit)
  local list = {}
  local _, class = UnitClass(unit)
  for _, family in ipairs(ns.GROUP_BUFFS) do
    if ns.FamilyEnabled(family) and ns.KnowsFamily(family) and not (family.manaOnly and NO_MANA[class]) then
      list[#list + 1] = family
    end
  end
  local blessings, extra = BlessingsFor(unit)
  for _, family in ipairs(blessings) do
    list[#list + 1] = family
  end
  return list, extra
end

-- Party frames ---------------------------------------------------------------------------------

local function FrameUnit(frame)
  local unit = frame.unit or frame.displayedUnit
  if not unit and frame.GetAttribute then
    unit = frame:GetAttribute("unit")
  end
  return type(unit) == "string" and unit or nil
end

-- Frames of addons we know by name, checked first: Blizzard's party frames, raid-style party
-- frames, raid frames (your own group), ElvUI and FlareUI. Any other unit frame addon is found by
-- the search further down. The player's own PlayerFrame isn't used: the icon row covers your own
-- buffs.
-- The frame names, built once: in the order they're checked, party first.
local PARTY_FRAME_NAMES, RAID_FRAME_NAMES = {}, {}
for i = 1, 5 do
  PARTY_FRAME_NAMES[#PARTY_FRAME_NAMES + 1] = "CompactPartyFrameMember" .. i
end
for i = 1, 4 do
  PARTY_FRAME_NAMES[#PARTY_FRAME_NAMES + 1] = "PartyMemberFrame" .. i
end
local POOL_SLOT = #PARTY_FRAME_NAMES -- Blizzard's party frame pool comes after these
for i = 1, 5 do
  PARTY_FRAME_NAMES[#PARTY_FRAME_NAMES + 1] = "ElvUF_PartyGroup1UnitButton" .. i
end
for i = 0, 4 do
  PARTY_FRAME_NAMES[#PARTY_FRAME_NAMES + 1] = "FlareUI_Party" .. i
end
for group = 1, 8 do
  for member = 1, 5 do
    PARTY_FRAME_NAMES[#PARTY_FRAME_NAMES + 1] = "CompactRaidGroup" .. group .. "Member" .. member
  end
end
for i = 1, 40 do
  PARTY_FRAME_NAMES[#PARTY_FRAME_NAMES + 1] = "CompactRaidFrame" .. i
end
for group = 1, 8 do
  for member = 1, 5 do
    for _, prefix in ipairs({ "ElvUF_Raid1Group", "ElvUF_Raid2Group", "ElvUF_Raid3Group", "ElvUF_RaidGroup" }) do
      RAID_FRAME_NAMES[#RAID_FRAME_NAMES + 1] = prefix .. group .. "UnitButton" .. member
    end
  end
end

local function AddPool(list)
  local pool = PartyFrame and PartyFrame.PartyMemberFramePool
  if pool and pool.EnumerateActive then
    pcall(function()
      for frame in pool:EnumerateActive() do
        list[#list + 1] = frame
      end
    end)
  end
end

local function CandidateFrames(raid)
  local list = {}
  local function AddNames(names)
    for index, name in ipairs(names) do
      local frame = _G[name]
      if type(frame) == "table" and frame.IsVisible then
        list[#list + 1] = frame
      end
      if names == PARTY_FRAME_NAMES and index == POOL_SLOT then
        AddPool(list)
      end
    end
  end
  AddNames(PARTY_FRAME_NAMES)
  if raid then
    AddNames(RAID_FRAME_NAMES)
  end
  return list
end

local ownButtons = {} -- our own buttons have a unit too: never anchor to them
local found = {}       -- group unit -> frame found by the search
local nextSearch, searchWait = 0, SEARCH_SECONDS

local function ResetSearch()
  nextSearch, searchWait = 0, SEARCH_SECONDS
end

-- Whether a frame can be a party member's frame: a visible, frame-sized frame whose "unit"
-- attribute is exactly that member, or in a raid the raid unit of the same person.
local function SearchMatch(frame, unit)
  local frameUnit = frame:GetAttribute("unit")
  if type(frameUnit) ~= "string" or ownButtons[frame] then
    return false
  end
  if frameUnit ~= unit and not (frameUnit:find("^raid%d+$") and UnitIsUnit(frameUnit, unit)) then
    return false
  end
  if (frame.IsForbidden and frame:IsForbidden()) or not frame:IsVisible() then
    return false
  end
  local width, height = frame:GetSize()
  return width >= 30 and height >= 12
end

local function IsMatch(frame, unit)
  local ok, match = pcall(SearchMatch, frame, unit)
  return ok and match
end

-- Looks through every frame for the members not found yet. That's slow, so it waits between
-- searches, and a frame found is kept for as long as it still shows that member. In a party, a
-- raid-style frame may show a member as raidN; in a raid every member is raidN already.
local function SearchFrames(missing, raid)
  if not EnumerateFrames or GetTime() < nextSearch then
    return
  end
  local foundAny = false
  local frame = EnumerateFrames()
  while frame do
    if frame.GetAttribute and not ownButtons[frame] then
      local ok, frameUnit = pcall(frame.GetAttribute, frame, "unit")
      if ok and type(frameUnit) == "string" then
        if missing[frameUnit] then
          if not found[frameUnit] and IsMatch(frame, frameUnit) then
            found[frameUnit] = frame
            foundAny = true
          end
        elseif not raid and frameUnit:find("^raid%d+$") then
          for unit in pairs(missing) do
            if not found[unit] and IsMatch(frame, unit) then
              found[unit] = frame
              foundAny = true
            end
          end
        end
      end
    end
    frame = EnumerateFrames(frame)
  end
  searchWait = foundAny and SEARCH_SECONDS or math.min(searchWait * 2, SEARCH_MAX_SECONDS)
  nextSearch = GetTime() + searchWait
end

-- units: the group's unit IDs (GroupUnits). Returns unit -> frame.
local function FindFrames(units, raid)
  local frames, wanted = {}, {}
  for _, unit in ipairs(units) do
    if UnitExists(unit) then
      wanted[unit] = true
    end
  end
  for _, frame in ipairs(CandidateFrames(raid)) do
    if frame:IsVisible() then
      local frameUnit = FrameUnit(frame)
      if frameUnit and UnitExists(frameUnit) then
        if wanted[frameUnit] then
          frames[frameUnit] = frames[frameUnit] or frame
        else
          -- the frame shows the person by another unit ID (raidN in a party, partyN in a raid)
          for _, unit in ipairs(units) do
            if wanted[unit] and not frames[unit] and UnitIsUnit(frameUnit, unit) then
              frames[unit] = frame
            end
          end
        end
      end
    end
  end

  -- Any other unit frame addon: members only, your own frame is left out.
  local missing = {}
  for _, unit in ipairs(units) do
    if wanted[unit] and not frames[unit] and unit ~= "player" and not UnitIsUnit(unit, "player") then
      local frame = found[unit]
      if frame and IsMatch(frame, unit) then
        frames[unit] = frame
      else
        found[unit] = nil
        missing[unit] = true
      end
    end
  end
  if next(missing) then
    SearchFrames(missing, raid)
    for unit in pairs(missing) do
      frames[unit] = found[unit]
    end
  end
  return frames
end

-- Buttons --------------------------------------------------------------------------------------

local buttons = {} -- buttons[unit][slot], made when first needed
local raidHolder   -- parent of the raid buttons, hidden by the game in combat
local ready = false
local dirty, sinceRefresh, sinceFullScan = true, 0, 0
local stale, rescanAll = {}, true -- in a raid: units whose buffs changed since the last read

-- The group's unit IDs: player and party1-4, or in a raid raid1 to raidN. Also whether it's a raid.
local function GroupUnits()
  if IsInRaid and IsInRaid() then
    local list = {}
    local count = math.min(GetNumGroupMembers and GetNumGroupMembers() or 0, #RAID_UNITS)
    for i = 1, count do
      list[i] = RAID_UNITS[i]
    end
    return list, true
  end
  return PARTY_UNITS, false
end

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
    local line = (ns.ReagentName(self.spell) or "Reagent") .. ": " .. ns.ReagentCount(self.spell)
    if ns.ReagentLow(self.spell) then
      GameTooltip:AddLine(line .. " (running low)", 1, 0.6, 0.2)
    else
      GameTooltip:AddLine(line, 1, 1, 1)
    end
  end
  if self.fellBack then
    local preferred = self.family.spells[1]
    GameTooltip:AddLine("Can't cast " .. preferred.name .. ", so this casts " .. self.spell.name .. ".",
      1, 0.6, 0.2, true)
  end
  if self.extra then
    GameTooltip:AddLine(who .. " has no blessing from you, so every blessing they're missing is shown.",
      0.6, 0.6, 0.6, true)
  end
  if self.family.blessing then
    GameTooltip:AddLine("Change blessings: /btrack party", 0.6, 0.6, 0.6)
  end
  GameTooltip:AddLine("Click to cast.", 0.6, 0.6, 0.6)
  GameTooltip:Show()
end

-- Out of combat only. A secure frame whose visibility the game sets itself: hidden in combat,
-- shown otherwise. Raid buttons cover part of the raid frames, and a healer clicking there in
-- combat must reach the raid frame, not cast a buff.
local function RaidHolder()
  if not raidHolder then
    raidHolder = CreateFrame("Frame", nil, UIParent, "SecureHandlerStateTemplate")
    raidHolder:SetAllPoints(UIParent)
    RegisterStateDriver(raidHolder, "visibility", "[combat] hide; show")
  end
  return raidHolder
end

local function CreateButton(parent)
  local button = CreateFrame("Button", nil, parent, "SecureActionButtonTemplate")
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
  button.roundParts = { button.icon, backdrop }

  button:SetScript("OnEnter", ShowTooltip)
  button:SetScript("OnLeave", function()
    GameTooltip:Hide()
  end)
  button:Hide()
  ownButtons[button] = true
  return button
end

-- Out of combat only: makes the unit's buttons up to slot.
local function GetButton(unit, slot)
  local row = buttons[unit]
  if not row then
    row = {}
    buttons[unit] = row
  end
  local parent = unit:find("^raid") and RaidHolder() or UIParent
  for index = #row + 1, slot do
    row[index] = CreateButton(parent)
    row[index].slot = index
  end
  return row[slot]
end

function ns.SetupParty()
  local party = ns.db.party or {}
  ns.db.party = party
  if party.enabled == nil then
    party.enabled = true
  end
  if party.refresh == nil then
    party.refresh = true
  end
  party.refreshSeconds = party.refreshSeconds or ns.DEFAULT_REFRESH_SECONDS
  if party.range == nil then
    party.range = true
  end
  if party.allBlessings == nil then
    party.allBlessings = true
  end
  party.rangeYards = party.rangeYards or ns.DEFAULT_RANGE_YARDS
  party.soon = nil -- 1.0.0: replaced by refresh, now on by default
  party.off = party.off or {}
  party.classes = party.classes or {}
  party.members = party.members or {}
  party.reagentWarn = party.reagentWarn or ns.DEFAULT_REAGENT_WARN
  if party.raid == nil then
    party.raid = true
  end
  ready = true
  ns.RefreshKnown()
end

-- Colors only: allowed in combat.
local function UpdateLooks()
  for _, row in pairs(buttons) do
    for _, button in ipairs(row) do
      if button:IsShown() and button.family then
        local unit, spell = button.unit, button.spell
        local has = auras[unit] and Remaining(unit, button.family)
        local done = has and not EndsSoon(has)
        if button.family.blessing and not has and ns.db.party.allBlessings and HasMyBlessing(unit) then
          done = true -- you blessed them in combat: the other choices are no longer needed
        end
        local _, noMana = IsUsable(spell.name)
        local reachable = UnitIsConnected(unit) and not UnitIsDeadOrGhost(unit) and InRange(spell.name, unit)
        -- secure group frames can reshuffle in combat: the frame may now show someone else
        local frameUnit = button.frame and FrameUnit(button.frame)
        local moved = frameUnit ~= nil and frameUnit ~= unit and not UnitIsUnit(frameUnit, unit)
        button.icon:SetDesaturated(done or moved or false)
        if TooFar(unit) then
          -- only in combat, when the button can't be hidden: invisible until they come back
          button:SetAlpha(0)
        elseif moved then
          button:SetAlpha(0.25)
          ns.SetFrameColor(button, ns.T.GREY)
        elseif done then
          button:SetAlpha(0.4)
          ns.SetFrameColor(button, ns.T.GREY)
        else
          button:SetAlpha(1)
          ns.SetFrameColor(button, ns.T.GOLD_DEEP)
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

-- Size of the buttons in a raid frame's corner, and how many fit in about a third of its width.
local function InsideFit(frame)
  local ok, width, height = pcall(frame.GetSize, frame)
  width, height = ok and width or 0, ok and height or 0
  local size = math.min(math.max(math.floor(height * 0.35), RAID_MIN_SIZE), RAID_MAX_SIZE)
  local fits = math.floor((width * RAID_WIDTH_SHARE + GAP) / (size + GAP))
  return size, math.max(math.min(fits, MAX_PER_UNIT), 1)
end

-- Where a unit's buttons go: beside the frame, on the side facing the middle of the screen
-- ("left"/"right"), or in a raid frame's top right corner ("corner", frames sit side by side).
local function SideOf(frame, raid)
  if raid then
    return "corner"
  end
  local frameX = (frame:GetCenter() or 0) * frame:GetEffectiveScale()
  local screenX = UIParent:GetCenter() * UIParent:GetEffectiveScale()
  return frameX < screenX and "right" or "left"
end

local function PlaceButton(row, slot, frame, side, size)
  local button = row[slot]
  button:SetSize(size, size)
  button:ClearAllPoints()
  if side == "corner" then
    if slot == 1 then
      button:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -1, -1)
    else
      button:SetPoint("RIGHT", row[slot - 1], "LEFT", -1, 0)
    end
  elseif slot == 1 then
    if side == "right" then
      button:SetPoint("LEFT", frame, "RIGHT", GAP, 0)
    else
      button:SetPoint("RIGHT", frame, "LEFT", -GAP, 0)
    end
  elseif side == "right" then
    button:SetPoint("LEFT", row[slot - 1], "RIGHT", GAP, 0)
  else
    button:SetPoint("RIGHT", row[slot - 1], "LEFT", -GAP, 0)
  end
  button:SetFrameStrata(frame:GetFrameStrata())
  button:SetFrameLevel(frame:GetFrameLevel() + 10)
end

function ns.UpdateParty()
  if not (ns.db and ready) then
    return
  end
  dirty, sinceRefresh = false, 0
  local units, raid = GroupUnits()
  local inGroup = {}
  -- In a party every member is read each time. In a raid only those with new buffs, and every
  -- member now and then.
  if sinceFullScan >= RAID_FULL_SCAN_SECONDS then
    rescanAll, sinceFullScan = true, 0
  end
  for _, unit in ipairs(units) do
    inGroup[unit] = true
    if not UnitExists(unit) then
      auras[unit] = nil
    elseif not raid or rescanAll or stale[unit] or not auras[unit] then
      ScanUnit(unit)
    end
  end
  for unit in pairs(auras) do
    if not inGroup[unit] then
      auras[unit], fromMe[unit] = nil, nil
    end
  end
  stale, rescanAll = {}, false
  if InCombatLockdown() then
    dirty = true -- lay out again when combat ends
    UpdateLooks()
    return
  end

  local party = ns.db.party
  local show = party.enabled and IsInGroup() and (party.raid or not raid)
  local frames = show and FindFrames(units, raid) or {}
  local needsOf, placeOf = {}, {}
  for _, unit in ipairs(units) do
    local needs = {}
    local frame = frames[unit]
    if frame and auras[unit] and UnitIsConnected(unit) and not UnitIsDeadOrGhost(unit) and not TooFar(unit) then
      local size, limit = SIZE, MAX_PER_UNIT
      if raid then
        size, limit = InsideFit(frame)
      end
      local families, extra = FamiliesFor(unit)
      for _, family in ipairs(families) do
        local remaining = Remaining(unit, family)
        if remaining == nil or (EndsSoon(remaining) and not extra[family]) then
          local spell, fellBack = ns.ChooseSpell(family)
          if spell and #needs < limit then
            needs[#needs + 1] = { family = family, spell = spell, fellBack = fellBack, extra = extra[family] }
          end
        end
      end
      if #needs > 0 then
        GetButton(unit, #needs) -- made here, in group order
        placeOf[unit] = { frame = frame, size = size, side = SideOf(frame, raid) }
      end
    end
    needsOf[unit] = needs
  end
  -- Every row, also those of units no longer in the group (their buttons hide). Attributes and
  -- points are set only when something changed: unit, spell, frame, size or side.
  for unit, row in pairs(buttons) do
    local needs, place = needsOf[unit] or {}, placeOf[unit]
    for slot, button in ipairs(row) do
      local need = needs[slot]
      if need then
        button.family, button.fellBack, button.extra = need.family, need.fellBack, need.extra
        ns.ApplyShape(button, ns.IsRound())
        if not (button:IsShown() and button.unit == unit and button.spell == need.spell and button.frame == place.frame
          and button.size == place.size and button.side == place.side) then
          button.unit, button.spell, button.frame = unit, need.spell, place.frame
          button.size, button.side = place.size, place.side
          button:SetAttribute("unit", unit)
          button:SetAttribute("spell", need.spell.name)
          button.icon:SetTexture(SpellIcon(need.spell.name) or ns.DEFAULT_ICON)
          PlaceButton(row, slot, place.frame, place.side, place.size)
          button:Show()
        end
      else
        button.family, button.frame = nil, nil
        if button:IsShown() then
          button:Hide()
        end
      end
    end
  end
  UpdateLooks()
end

function ns.PartyChanged()
  dirty = true
  ResetSearch()
  ns.RefreshPartyOptions()
end

local eventFrame = CreateFrame("Frame")
for _, event in ipairs({
  "GROUP_ROSTER_UPDATE", "PLAYER_ENTERING_WORLD", "PLAYER_REGEN_ENABLED", "SPELLS_CHANGED",
  "BAG_UPDATE_DELAYED", "UNIT_AURA", "UNIT_CONNECTION", "UNIT_FLAGS",
}) do
  pcall(eventFrame.RegisterEvent, eventFrame, event)
end
local function IsGroupUnit(unit)
  return type(unit) == "string" and (unit == "player" or unit:find("^party%d$") or unit:find("^raid%d+$")) ~= nil
end

-- In a raid, buffs are read again only for members with UNIT_AURA. An event for "player" or
-- partyN marks that person's raidN too, from a map made once per roster change.
local raidOf = {}
local rosterSize

local function MapRaidUnits()
  raidOf = {}
  if not (IsInRaid and IsInRaid()) then
    return
  end
  local count = math.min(GetNumGroupMembers and GetNumGroupMembers() or 0, #RAID_UNITS)
  for _, unit in ipairs(PARTY_UNITS) do
    if UnitExists(unit) then
      for i = 1, count do
        if UnitIsUnit(RAID_UNITS[i], unit) then
          raidOf[unit] = RAID_UNITS[i]
          break
        end
      end
    end
  end
end

local function MarkStale(unit)
  stale[unit] = true
  local raidUnit = raidOf[unit]
  if raidUnit then
    stale[raidUnit] = true
  end
end

eventFrame:SetScript("OnEvent", function(_, event, unit)
  if not ns.db then
    return
  end
  if event == "UNIT_AURA" or event == "UNIT_CONNECTION" or event == "UNIT_FLAGS" then
    if not IsGroupUnit(unit) then
      return
    end
    if event == "UNIT_AURA" then
      MarkStale(unit)
    end
  end
  if event == "SPELLS_CHANGED" then
    ns.RefreshKnown()
  end
  if event == "SPELLS_CHANGED" or event == "BAG_UPDATE_DELAYED" then
    ns.CheckReagents()
  end
  dirty = true
  if event == "GROUP_ROSTER_UPDATE" or event == "PLAYER_ENTERING_WORLD" or event == "PLAYER_REGEN_ENABLED" then
    rescanAll = true
  end
  if event == "GROUP_ROSTER_UPDATE" or event == "PLAYER_ENTERING_WORLD" then
    MapRaidUnits()
    -- In a raid the roster changes often (people move between groups): the slow frame search
    -- keeps its growing wait unless the raid got bigger or smaller.
    local size = GetNumGroupMembers and GetNumGroupMembers() or 0
    if event == "PLAYER_ENTERING_WORLD" or not (IsInRaid and IsInRaid()) or size ~= rosterSize then
      ResetSearch()
    end
    rosterSize = size
  end
  if event == "GROUP_ROSTER_UPDATE" then
    ns.RefreshPartyOptions()
  end
end)

-- Called from the main tick: refreshes after events, and every second for timers, range and
-- frames that moved.
function ns.PartyTick(elapsed)
  sinceRefresh = sinceRefresh + elapsed
  sinceFullScan = sinceFullScan + elapsed
  local raid = IsInRaid and IsInRaid()
  if (dirty and not InCombatLockdown() and (not raid or sinceRefresh >= RAID_DIRTY_SECONDS))
    or sinceRefresh >= REFRESH_SECONDS then
    ns.UpdateParty()
  end
end

-- /btrack debug: what the party buttons see, for bug reports.
function ns.PartyDebug()
  local function Say(text)
    print(ns.PREFIX .. text)
  end
  local function FrameName(frame)
    if not frame then
      return "none"
    end
    local ok, name = pcall(frame.GetName, frame)
    name = ok and name or "unnamed"
    local okSize, width, height = pcall(frame.GetSize, frame)
    if okSize and width then
      name = string.format("%s (%dx%d)", name, width, height)
    end
    return name
  end
  local party = ns.db.party
  Say(string.format("party buttons %s, in group %s, in combat %s",
    party.enabled and "on" or "off", tostring(IsInGroup()), tostring(InCombatLockdown())))
  local known = {}
  for _, family in ipairs(ns.GROUP_BUFFS) do
    if ns.KnowsFamily(family) then
      known[#known + 1] = family.key .. (ns.FamilyEnabled(family) and "" or " (off)")
    end
  end
  for _, family in ipairs(ns.KnownBlessings()) do
    known[#known + 1] = family.key
  end
  Say("buffs you can give: " .. (#known > 0 and table.concat(known, ", ") or "none"))
  for i = 0, 4 do
    local frame = _G["FlareUI_Party" .. i]
    if frame then
      local ok, unit = pcall(frame.GetAttribute, frame, "unit")
      Say(string.format("FlareUI_Party%d: unit %s, visible %s", i, tostring(ok and unit), tostring(frame:IsVisible())))
    end
  end
  local units, raid = GroupUnits()
  local frames = FindFrames(units, raid)
  for _, unit in ipairs(units) do
    if UnitExists(unit) then
      local needs = {}
      for _, family in ipairs(FamiliesFor(unit)) do
        local remaining = auras[unit] and Remaining(unit, family)
        needs[#needs + 1] = family.key .. "=" .. (remaining == nil and "missing"
          or remaining == math.huge and "has" or string.format("%ds", remaining))
      end
      local shown = 0
      for _, button in ipairs(buttons[unit] or {}) do
        if button:IsShown() then
          shown = shown + 1
        end
      end
      local distance = Distance(unit)
      Say(string.format("%s %s: frame %s, buffs read %s, %s, blessing from you %s, buttons %d, distance %s%s",
        unit, GetUnitName(unit, false) or "?", FrameName(frames[unit]), auras[unit] and "yes" or "no",
        #needs > 0 and table.concat(needs, " ") or "nothing to give", HasMyBlessing(unit) and "yes" or "no", shown,
        distance and string.format("%d yd", distance) or "unknown", TooFar(unit) and " (too far)" or ""))
    end
  end
end
