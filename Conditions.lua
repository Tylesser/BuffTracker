local _, ns = ...
local L = ns.L

-- Conditions: where and when the tracked buffs show (the user's request, 2026-11-20: "sometimes I don't want to see
-- my tracked buffs, like in dungeons, in raids; but out of a dungeon in a party I may want to"). On top of each
-- buff's mode (missing / active / always), three independent tests, all of which must pass:
--   where:  open world, cities and inns (resting), dungeons (5-man and scenario instances), raids, battlegrounds
--           and arenas (IsInInstance's type, else IsResting)
--   group:  solo, in a party, in a raid group (IsInRaid, IsInGroup)
--   combat: in and out of combat, only in combat, only out of combat
--   talents: with your primary or secondary talents (dual spec; 2026-11-22), where the game has them:
--           C_SpecializationInfo.GetActiveSpecGroup (Forever's own talent frame uses it), else
--           GetActiveTalentGroup; not on Retail, where you have one talent group per specialization
--   role:   your group role (2026-11-26, the user's request): tank, healer, damage, or no role set
--           (UnitGroupRolesAssigned("player"): TANK / HEALER / DAMAGER / NONE; a role the game doesn't tell
--           hides nothing)
-- A condition set is { places = { [key] = false }, groups = { [key] = false }, talents = { [key] = false },
-- roles = { [key] = false },
-- combat = "in" | "out" | nil }: false =
-- hidden there, nil = shown (so entries saved before conditions existed show everywhere, as before). The whole row
-- has one set (`db.conditions`); a buff with its own (`entry.conditions`) uses that instead. While the row is
-- unlocked (moving it, Edit Mode) every icon shows, as before. The icons are plain frames, so they may change in a
-- fight; the click-to-cast overlays are secure and only follow out of combat.

-- label: the check box; text: the same in the summary ("not in <text>", "not <text>", "only <text>"), written for
-- that place in a sentence (translations use the case the sentence needs there).
ns.PLACES = {
  { key = "world", label = L["Open world"], text = L["open world"] },
  { key = "rest", label = L["Cities and inns"], text = L["cities and inns"] },
  { key = "dungeon", label = L["Dungeons"], text = L["dungeons"] },
  { key = "raid", label = L["Raids"], text = L["raids"] },
  { key = "pvp", label = L["Battlegrounds and arenas"], text = L["battlegrounds and arenas"] },
}
ns.GROUPS = {
  { key = "solo", label = L["Solo"], text = L["solo"] },
  { key = "party", label = L["In a party"], text = L["in a party"] },
  { key = "raid", label = L["In a raid group"], text = L["in a raid group"] },
}
ns.COMBAT = {
  { key = "any", label = L["In and out of combat"] },
  { key = "in", label = L["Only in combat"] },
  { key = "out", label = L["Only out of combat"] },
}

ns.TALENTS = {
  { key = "primary", label = L["Primary talents"] },
  { key = "secondary", label = L["Secondary talents"] },
}

ns.ROLES = {
  { key = "tank", label = L["Tank"], text = L["as tank"] },
  { key = "healer", label = L["Healer"], text = L["as healer"] },
  { key = "damage", label = L["Damage"], text = L["as damage"] },
  { key = "none", label = L["No role set"], text = L["with no role set"] },
}
local ROLE_KEYS = { TANK = "tank", HEALER = "healer", DAMAGER = "damage", NONE = "none" }

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

-- Whether this game has two talent groups to choose between (dual spec): Forever, the Classic versions; not Retail.
function ns.HasTalentGroups()
  if WOW_PROJECT_ID and WOW_PROJECT_MAINLINE and WOW_PROJECT_ID == WOW_PROJECT_MAINLINE then
    return false
  end
  return (C_SpecializationInfo and type(C_SpecializationInfo.GetActiveSpecGroup) == "function")
    or type(GetActiveTalentGroup) == "function"
end

-- Your active talents: "primary" or "secondary"; nil while the game doesn't know them yet (early in a login: the
-- talents rule then hides nothing, and PLAYER_TALENT_UPDATE redraws the row).
function ns.CurrentTalents()
  if C_SpecializationInfo and Ask(C_SpecializationInfo.IsInitialized) == false then
    return nil
  end
  local group
  if C_SpecializationInfo then
    group = Ask(C_SpecializationInfo.GetActiveSpecGroup)
  end
  if group == nil then
    group = Ask(GetActiveTalentGroup)
  end
  return group == 2 and "secondary" or "primary"
end

-- Whether this game has group roles (UnitGroupRolesAssigned).
function ns.HasRoles()
  return type(UnitGroupRolesAssigned) == "function"
end

-- Your group role: "tank", "healer", "damage" or "none"; nil when the game doesn't say.
function ns.CurrentRole()
  local role = Ask(UnitGroupRolesAssigned, "player")
  return type(role) == "string" and ROLE_KEYS[role] or nil
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
  local talents = type(conditions.talents) == "table" and ns.HasTalentGroups() and ns.CurrentTalents()
  if talents and conditions.talents[talents] == false then
    return false
  end
  local role = type(conditions.roles) == "table" and ns.HasRoles() and ns.CurrentRole()
  if role and conditions.roles[role] == false then
    return false
  end
  if conditions.combat == "in" and not ns.InCombatNow() then
    return false
  elseif conditions.combat == "out" and ns.InCombatNow() then
    return false
  end
  return true
end

-- "Warn me to remove it" (optional, off by default; the user's request, 2026-11-21): a buff that has rules, is on, and
-- is somewhere its rules say no (Righteous Fury out of a dungeon, say) shows in the row as "remove", is named once in
-- chat, and its icon's click removes it (out of combat: the secure "cancelaura" action, forever SecureTemplates.lua).
function ns.Unwanted(entry, state)
  if not (ns.db and ns.db.warnUnwanted and entry) then
    return false
  end
  local conditions = ns.EntryConditions(entry)
  if type(conditions) ~= "table" or ns.ConditionsText(conditions) == L["Everywhere"] or ns.ConditionsMet(conditions) then
    return false
  end
  return state and state.known and state.active and true or false
end

-- What a click does on an unwanted buff's icon: remove it by name, or a weapon enchant by its slot.
function ns.RemoveAction(entry)
  if entry.slot then
    return { remove = true, slot = entry.slot }
  end
  return { remove = true, spell = entry.name }
end

function ns.SetWarnUnwanted(on)
  ns.db.warnUnwanted = on and true or false
  ns.UpdateDisplay()
  if ns.RefreshConditions then
    ns.RefreshConditions()
  end
end

-- The conditions a buff follows: its own, else the row's.
function ns.EntryConditions(entry)
  return entry and entry.conditions or ns.db.conditions
end

function ns.CopyConditions(conditions)
  local copy = { places = {}, groups = {}, talents = {}, roles = {} }
  if type(conditions) == "table" then
    for key, value in pairs(conditions.places or {}) do
      copy.places[key] = value
    end
    for key, value in pairs(conditions.groups or {}) do
      copy.groups[key] = value
    end
    for key, value in pairs(conditions.talents or {}) do
      copy.talents[key] = value
    end
    for key, value in pairs(conditions.roles or {}) do
      copy.roles[key] = value
    end
    copy.combat = conditions.combat
  end
  return copy
end

-- "a, b and c" / "a, b or c": lastTwo is L["%s and %s"] or L["%s or %s"].
local function JoinList(items, lastTwo)
  if #items < 2 then
    return items[1]
  end
  return lastTwo:format(table.concat(items, ", ", 1, #items - 1), items[#items])
end

-- The first letter in capitals; also a Cyrillic one (string.upper only knows A-Z).
local function Capitalize(text)
  local first, second = text:byte(1, 2)
  if first == 0xD0 and second and second >= 0xB0 and second <= 0xBF then -- а-п
    return string.char(0xD0, second - 0x20) .. text:sub(3)
  elseif first == 0xD1 and second and second >= 0x80 and second <= 0x8F then -- р-я
    return string.char(0xD0, second + 0x20) .. text:sub(3)
  end
  return text:sub(1, 1):upper() .. text:sub(2)
end

-- "Everywhere", or what's left out: "Not in dungeons and raids; only out of combat". inSentence: no capital
-- first letter (for a chat line that quotes it).
function ns.ConditionsText(conditions, inSentence)
  if type(conditions) ~= "table" then
    return L["Everywhere"]
  end
  local parts = {}
  local places = {}
  for _, place in ipairs(ns.PLACES) do
    if conditions.places and conditions.places[place.key] == false then
      places[#places + 1] = place.text
    end
  end
  if #places == #ns.PLACES then
    parts[#parts + 1] = L["nowhere"]
  elseif #places > 0 then
    parts[#parts + 1] = L["not in %s"]:format(JoinList(places, L["%s and %s"]))
  end
  local groups = {}
  for _, group in ipairs(ns.GROUPS) do
    if conditions.groups and conditions.groups[group.key] == false then
      groups[#groups + 1] = group.text
    end
  end
  if #groups == #ns.GROUPS then
    parts[#parts + 1] = L["never in any group"]
  elseif #groups > 0 then
    parts[#parts + 1] = L["not %s"]:format(JoinList(groups, L["%s or %s"]))
  end
  if conditions.talents and ns.HasTalentGroups() then
    local primary, secondary = conditions.talents.primary ~= false, conditions.talents.secondary ~= false
    if not primary and not secondary then
      parts[#parts + 1] = L["never with either talents"]
    elseif not primary then
      parts[#parts + 1] = L["only with secondary talents"]
    elseif not secondary then
      parts[#parts + 1] = L["only with primary talents"]
    end
  end
  if conditions.roles and ns.HasRoles() then
    local shown = {}
    for _, role in ipairs(ns.ROLES) do
      if conditions.roles[role.key] ~= false then
        shown[#shown + 1] = role.text
      end
    end
    if #shown == 0 then
      parts[#parts + 1] = L["never with any role"]
    elseif #shown < #ns.ROLES then
      parts[#parts + 1] = L["only %s"]:format(JoinList(shown, L["%s or %s"]))
    end
  end
  if conditions.combat == "in" then
    parts[#parts + 1] = L["only in combat"]
  elseif conditions.combat == "out" then
    parts[#parts + 1] = L["only out of combat"]
  end
  if #parts == 0 then
    return L["Everywhere"]
  end
  local text = table.concat(parts, "; ")
  return inSentence and text or Capitalize(text)
end


-- Sets one condition. `target` = "row" or a tracked entry; kind = "place" / "group" / "talents" / "role" /
-- "combat"; for place, group, talents and role,
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
  conditions.talents = conditions.talents or {}
  conditions.roles = conditions.roles or {}
  -- (false = hidden there; `value == false and false or nil` would always give nil)
  local hidden = nil
  if value == false then
    hidden = false
  end
  if kind == "place" then
    conditions.places[key] = hidden
  elseif kind == "group" then
    conditions.groups[key] = hidden
  elseif kind == "talents" then
    conditions.talents[key] = hidden
  elseif kind == "role" then
    conditions.roles[key] = hidden
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
