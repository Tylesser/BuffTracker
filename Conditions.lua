local _, ns = ...

-- Conditions: where and when the tracked buffs show (the user's request, 2026-11-20: "sometimes I don't want to see
-- my tracked buffs, like in dungeons, in raids; but out of a dungeon in a party I may want to"). On top of each
-- buff's mode (missing / active / always), three independent tests, all of which must pass:
--   where:  open world, cities and inns (resting), dungeons (5-man and scenario instances), raids, battlegrounds
--           and arenas (IsInInstance's type, else IsResting)
--   group:  solo, in a party, in a raid group (IsInRaid, IsInGroup)
--   combat: in and out of combat, only in combat, only out of combat
-- A condition set is { places = { [key] = false }, groups = { [key] = false }, combat = "in" | "out" | nil }: false =
-- hidden there, nil = shown (so entries saved before conditions existed show everywhere, as before). The whole row
-- has one set (`db.conditions`); a buff with its own (`entry.conditions`) uses that instead. While the row is
-- unlocked (moving it, Edit Mode) every icon shows, as before. The icons are plain frames, so they may change in a
-- fight; the click-to-cast overlays are secure and only follow out of combat.

ns.PLACES = {
  { key = "world", label = "Open world" },
  { key = "rest", label = "Cities and inns" },
  { key = "dungeon", label = "Dungeons" },
  { key = "raid", label = "Raids" },
  { key = "pvp", label = "Battlegrounds and arenas" },
}
ns.GROUPS = {
  { key = "solo", label = "Solo" },
  { key = "party", label = "In a party" },
  { key = "raid", label = "In a raid group" },
}
ns.COMBAT = {
  { key = "any", label = "In and out of combat" },
  { key = "in", label = "Only in combat" },
  { key = "out", label = "Only out of combat" },
}

local function Plain(value)
  if value == nil then
    return nil
  end
  if issecretvalue and issecretvalue(value) then
    return nil
  end
  if canaccessvalue and not canaccessvalue(value) then
    return nil
  end
  return value
end

local function Ask(fn, ...)
  if type(fn) ~= "function" then
    return nil
  end
  local ok, a, b = pcall(fn, ...)
  if not ok then
    return nil
  end
  return Plain(a), Plain(b)
end

-- Where you are: "world", "rest", "dungeon", "raid" or "pvp".
function ns.CurrentPlace()
  local inInstance, kind = Ask(IsInInstance)
  if inInstance == true then
    if kind == "raid" then
      return "raid"
    elseif kind == "pvp" or kind == "arena" then
      return "pvp"
    end
    return "dungeon" -- "party", "scenario" and anything new
  end
  if Ask(IsResting) == true then
    return "rest"
  end
  return "world"
end

-- Your group: "solo", "party" or "raid".
function ns.CurrentGroup()
  if Ask(IsInRaid) == true then
    return "raid"
  elseif Ask(IsInGroup) == true then
    return "party"
  end
  return "solo"
end

-- In a fight (also while PLAYER_REGEN_DISABLED runs, before the lockdown starts).
function ns.InCombatNow()
  if ns.combatStarting then
    return true
  end
  if InCombatLockdown and InCombatLockdown() then
    return true
  end
  return Ask(UnitAffectingCombat, "player") == true
end

function ns.ConditionsMet(conditions)
  if type(conditions) ~= "table" then
    return true
  end
  if type(conditions.places) == "table" and conditions.places[ns.CurrentPlace()] == false then
    return false
  end
  if type(conditions.groups) == "table" and conditions.groups[ns.CurrentGroup()] == false then
    return false
  end
  if conditions.combat == "in" and not ns.InCombatNow() then
    return false
  elseif conditions.combat == "out" and ns.InCombatNow() then
    return false
  end
  return true
end

-- The conditions a buff follows: its own, else the row's.
function ns.EntryConditions(entry)
  return entry and entry.conditions or ns.db.conditions
end

function ns.CopyConditions(conditions)
  local copy = { places = {}, groups = {} }
  if type(conditions) == "table" then
    for key, value in pairs(conditions.places or {}) do
      copy.places[key] = value
    end
    for key, value in pairs(conditions.groups or {}) do
      copy.groups[key] = value
    end
    copy.combat = conditions.combat
  end
  return copy
end

-- "Everywhere", or what's left out: "Not in dungeons and raids; only out of combat".
function ns.ConditionsText(conditions)
  if type(conditions) ~= "table" then
    return "Everywhere"
  end
  local parts = {}
  local places = {}
  for _, place in ipairs(ns.PLACES) do
    if conditions.places and conditions.places[place.key] == false then
      places[#places + 1] = place.label:lower()
    end
  end
  if #places == #ns.PLACES then
    parts[#parts + 1] = "nowhere"
  elseif #places > 0 then
    parts[#parts + 1] = "not in " .. (#places > 1 and table.concat(places, ", ", 1, #places - 1) .. " and "
      .. places[#places] or places[1])
  end
  local groups = {}
  for _, group in ipairs(ns.GROUPS) do
    if conditions.groups and conditions.groups[group.key] == false then
      groups[#groups + 1] = group.label:lower()
    end
  end
  if #groups == #ns.GROUPS then
    parts[#parts + 1] = "never in any group"
  elseif #groups > 0 then
    parts[#parts + 1] = "not " .. (#groups > 1 and table.concat(groups, ", ", 1, #groups - 1) .. " or "
      .. groups[#groups] or groups[1])
  end
  if conditions.combat == "in" then
    parts[#parts + 1] = "only in combat"
  elseif conditions.combat == "out" then
    parts[#parts + 1] = "only out of combat"
  end
  if #parts == 0 then
    return "Everywhere"
  end
  local text = table.concat(parts, "; ")
  return text:sub(1, 1):upper() .. text:sub(2)
end

-- Sets one condition. `target` = "row" or a tracked entry; kind = "place" / "group" / "combat"; for place and group,
-- `on` = shown there; for combat, `value` = "any" / "in" / "out".
function ns.SetCondition(target, kind, key, value)
  local conditions
  if target == "row" then
    ns.db.conditions = ns.db.conditions or ns.CopyConditions(nil)
    conditions = ns.db.conditions
  else
    target.conditions = target.conditions or ns.CopyConditions(ns.db.conditions)
    conditions = target.conditions
  end
  conditions.places = conditions.places or {}
  conditions.groups = conditions.groups or {}
  -- (false = hidden there; `value == false and false or nil` would always give nil)
  local hidden = nil
  if value == false then
    hidden = false
  end
  if kind == "place" then
    conditions.places[key] = hidden
  elseif kind == "group" then
    conditions.groups[key] = hidden
  elseif kind == "combat" then
    conditions.combat = (key == "in" or key == "out") and key or nil
  end
  ns.Changed()
end

-- A buff's own conditions on (a copy of the row's to start from) or off (it follows the row again).
function ns.SetOwnConditions(entry, own)
  if own then
    entry.conditions = entry.conditions or ns.CopyConditions(ns.db.conditions)
  else
    entry.conditions = nil
  end
  ns.Changed()
end
