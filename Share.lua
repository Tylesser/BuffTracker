local _, root = ...
-- Buff Tracker's ns, or Codex's codex.buffs (its `codex` field is Codex's ns): this file is the same in both
local inCodex = type(root.buffs) == "table" and root.buffs.codex == root
local ns = inCodex and root.buffs or root
local L = root.L

-- Sharing blessings (2026-11-28, the user's request): paladins in a group who run Buff Tracker or Codex tell each
-- other which blessing they give each class (and their per-member choices) through hidden addon messages. The
-- Party buffs page lists the other paladins' choices, chat warns once when two of you chose the same blessing for a
-- class, and the party buttons (with "every blessing" on) leave a blessing another paladin is assigned to them.
--
-- Messages (prefix ns.SHARE_PREFIX, the group's channel), "<version>:<kind>:<body>":
--   1:H:WARRIOR=M,MAGE=W,...   your choice per class (resets what others knew of you, members included)
--   1:M:Name-Realm=K,...       your per-member choices for members of this group (after an H, as many as needed)
--   1:Q                        "tell me yours": every sharing paladin answers with H (+ M)
--   1:X                        "I stopped sharing" (not a paladin any more, buttons or sharing switched off)
-- Codes: M Might, W Wisdom, K Kings, S Salvation, L Light, Y Sanctuary, N none (or a blessing the sender doesn't
-- know). Other versions and kinds are ignored, as are messages from yourself and from anyone not in the group.
-- Nothing is sent in combat or while the game locks chat messages (C_ChatInfo.InChatMessagingLockdown): then it
-- waits for PLAYER_REGEN_ENABLED. What arrives may be secret while locked (CHAT_MSG_ADDON SecretInChatMessagingLockdown):
-- such messages are dropped unread.

ns.SHARE_PREFIX = "TylesserBless" -- (at most 16 characters)
local VERSION = "1"
local MAX_BODY = 230 -- an addon message holds 255 bytes
local CODE = { might = "M", wisdom = "W", kings = "K", salvation = "S", light = "L", sanctuary = "Y", none = "N" }
local KEY = {}
for key, code in pairs(CODE) do
  KEY[code] = key
end

-- What the other paladins share: [lower-case Name-Realm] = { full = "Name-Realm", name = as GetUnitName shows them,
-- classes = { [CLASS] = key }, members = { [name as GetUnitName shows them] = key } }. key "none" = nothing.
ns.shared = {}

local lastSent -- the last state sent (all messages joined), to send again only when it changed
local pending, scheduled = false, false -- pending: a send waits for the end of combat / the chat lock
local wantForce, wantQuery = false, false -- what the next send does besides sending a changed state
local roster = {} -- [lower-case full name] = true: who was in the group at the last roster update
local wasInGroup = false
local warned = {} -- [paladin .. "\t" .. what .. "\t" .. key] = true: conflicts already named in chat

local function Secret(value)
  return issecretvalue and issecretvalue(value) or false
end

local function Realm()
  local realm = GetNormalizedRealmName and GetNormalizedRealmName()
  if (not realm or realm == "") and GetRealmName then
    realm = (GetRealmName() or ""):gsub("[%s%-]", "")
  end
  return realm ~= "" and realm or nil
end

-- "Name" (your realm) or "Name-Realm" -> "Name-Realm"
local function FullName(name)
  if type(name) ~= "string" or name == "" then
    return nil
  end
  if name:find("-", 1, true) then
    return name
  end
  local realm = Realm()
  return realm and (name .. "-" .. realm) or name
end
ns.ShareFullName = FullName

-- "Name-Realm" -> as GetUnitName(unit, true) shows it here ("Name" on your own realm)
local function LocalName(full)
  local realm = Realm()
  if realm and full:sub(-(#realm + 1)) == "-" .. realm then
    return full:sub(1, -(#realm + 2))
  end
  return full
end

local function OwnFull()
  return FullName(UnitName and UnitName("player"))
end

-- player + party1-4, or raid1..N
local function GroupUnits()
  local units = {}
  if IsInRaid and IsInRaid() then
    for index = 1, (GetNumGroupMembers and GetNumGroupMembers() or 0) do
      units[#units + 1] = "raid" .. index
    end
  else
    units[1] = "player"
    for index = 1, 4 do
      units[#units + 1] = "party" .. index
    end
  end
  return units
end

local function InGroup()
  return IsInGroup and IsInGroup() or false
end

-- Whether two "Name-Realm" texts are one character: the name's first word (Forever's names can carry a surname)
-- and the realm when both have one.
local function SameName(a, b)
  local nameA, realmA = a:lower():match("^([^%-]+)%-?(.*)$")
  local nameB, realmB = b:lower():match("^([^%-]+)%-?(.*)$")
  if not (nameA and nameB) or nameA:match("^(%S+)") ~= nameB:match("^(%S+)") then
    return false
  end
  return realmA == "" or realmB == "" or realmA == realmB
end

-- The group's members other than you: { { unit, name (GetUnitName), full, class } }
local function Members()
  local list = {}
  for _, unit in ipairs(GroupUnits()) do
    if UnitExists and GetUnitName and UnitExists(unit) and ns.SameUnit(unit, "player") ~= true then
      local name = GetUnitName(unit, true)
      local full = name and not Secret(name) and FullName(name)
      if full then
        local _, class = UnitClass(unit)
        list[#list + 1] = { unit = unit, name = name, full = full, class = class }
      end
    end
  end
  return list
end

local function Channel()
  local instance = LE_PARTY_CATEGORY_INSTANCE
  if instance and IsInGroup(instance) and not IsInGroup(LE_PARTY_CATEGORY_HOME) then
    return "INSTANCE_CHAT"
  end
  if IsInRaid and IsInRaid() then
    return "RAID"
  end
  return InGroup() and "PARTY" or nil
end

local function Blocked()
  if InCombatLockdown and InCombatLockdown() then
    return true
  end
  local chat = C_ChatInfo
  for _, name in ipairs({ "InChatMessagingLockdown", "AreOutgoingAddonChatMessagesRestricted" }) do
    local check = chat and chat[name]
    if check then
      local ok, locked = pcall(check)
      if ok and locked == true then
        return true
      end
    end
  end
  return false
end

local function SendMessage(text, channel)
  local send = C_ChatInfo and C_ChatInfo.SendAddonMessage or SendAddonMessage
  if send then
    pcall(send, ns.SHARE_PREFIX, text, channel)
  end
end

-- The class tokens choices are sent for: every class with a default blessing, and any you chose one for.
function ns.ShareClasses()
  local list, seen = {}, {}
  for class in pairs(ns.DEFAULT_BLESSINGS) do
    list[#list + 1], seen[class] = class, true
  end
  for class in pairs(ns.db.party.classes) do
    if not seen[class] and type(class) == "string" then
      list[#list + 1] = class
    end
  end
  table.sort(list)
  return list
end

-- A choice as you'll really cast it: "none" for none or a blessing you don't know.
local function Effective(key)
  local family = key and ns.FAMILY[key]
  if family and family.blessing and ns.KnowsFamily(family) then
    return key
  end
  return "none"
end

-- Whether you share: you know a blessing, party buttons are on and "Share my blessings" is on.
function ns.SharesBlessings()
  local party = ns.db and ns.db.party
  return party ~= nil and party.enabled and party.share ~= false and #ns.KnownBlessings() > 0
end

-- Your state as messages (H first, then M chunks).
function ns.EncodeShare()
  local party = ns.db.party
  local pairsList = {}
  for _, class in ipairs(ns.ShareClasses()) do
    local key = Effective(party.classes[class] or ns.DEFAULT_BLESSINGS[class])
    pairsList[#pairsList + 1] = class .. "=" .. CODE[key]
  end
  local messages = { VERSION .. ":H:" .. table.concat(pairsList, ",") }
  local body = ""
  for _, member in ipairs(Members()) do
    local own = party.members[member.name]
    if own then
      local item = member.full .. "=" .. CODE[own == "none" and "none" or Effective(own)]
      if #body + #item + 1 > MAX_BODY then
        messages[#messages + 1] = VERSION .. ":M:" .. body
        body = ""
      end
      body = body == "" and item or (body .. "," .. item)
    end
  end
  if body ~= "" then
    messages[#messages + 1] = VERSION .. ":M:" .. body
  end
  return messages
end

-- Sends your state when it changed (force: also when it didn't, e.g. for someone who just joined).
function ns.ShareSend(force, query)
  local channel = Channel()
  if not (ns.db and channel) then
    return
  end
  if Blocked() then
    pending = true
    wantForce, wantQuery = wantForce or force or false, wantQuery or query or false
    return
  end
  pending = false
  if not ns.SharesBlessings() then
    if lastSent and lastSent ~= "X" then
      SendMessage(VERSION .. ":X", channel)
    end
    lastSent = "X"
  else
    local messages = ns.EncodeShare()
    local joined = table.concat(messages, "\n")
    if force or joined ~= lastSent then
      for _, message in ipairs(messages) do
        SendMessage(message, channel)
      end
      lastSent = joined
    end
  end
  if query then
    SendMessage(VERSION .. ":Q", channel)
  end
end

local function Later(seconds, force, query)
  wantForce, wantQuery = wantForce or force or false, wantQuery or query or false
  if scheduled then
    return
  end
  scheduled = true
  local function Run()
    scheduled = false
    local again, ask = wantForce, wantQuery
    wantForce, wantQuery = false, false
    ns.ShareSend(again, ask)
  end
  if C_Timer and C_Timer.After then
    C_Timer.After(seconds, Run)
  else
    Run()
  end
end

-- Your choices changed (Party.lua ns.PartyChanged): send them a moment later.
function ns.ShareChanged()
  if InGroup() then
    Later(1)
  end
end

-- Paladins who left the group are forgotten; a new member gets your state.
local function UpdateRoster()
  if not InGroup() then
    ns.shared, roster, wasInGroup, lastSent = {}, {}, false, nil
    return false
  end
  local now, joined = {}, false
  for _, member in ipairs(Members()) do
    local key = member.full:lower()
    now[key] = true
    if not roster[key] then
      joined = true
    end
  end
  for key in pairs(ns.shared) do
    if not now[key] then
      ns.shared[key] = nil
    end
  end
  roster = now
  local first = not wasInGroup
  wasInGroup = true
  if first then
    Later(2, true, true) -- just joined (or logged in in a group): send yours and ask for theirs
  elseif joined then
    Later(2, true)
  end
  return true
end

local function Parse(body)
  local list = {}
  for name, code in (body or ""):gmatch("([^,=]+)=(%u)") do
    if KEY[code] then
      list[name] = KEY[code]
    end
  end
  return list
end

-- A message from someone (CHAT_MSG_ADDON). Returns what it did (tests): "H", "M", "Q", "X" or nil.
function ns.ShareReceive(prefix, text, sender)
  if Secret(prefix) or Secret(text) or Secret(sender) or prefix ~= ns.SHARE_PREFIX then
    return nil
  end
  if type(text) ~= "string" or type(sender) ~= "string" or not ns.db then
    return nil
  end
  local full = FullName(sender)
  if not full or SameName(full, OwnFull() or "") then
    return nil
  end
  local member
  for _, each in ipairs(Members()) do
    if SameName(each.full, full) then
      member = each
      break
    end
  end
  if not member then
    return nil -- not in your group (any more)
  end
  local version, kind, body = text:match("^(%d+):(%u):?(.*)$")
  if version ~= VERSION then
    return nil
  end
  local key = member.full:lower()
  if kind == "H" then
    -- (full: the sender's own spelling, which every paladin compares in TakenByOther)
    ns.shared[key] = { full = full, name = member.name, classes = Parse(body), members = {} }
  elseif kind == "M" then
    local entry = ns.shared[key]
    if not entry then
      return nil
    end
    for name, blessing in pairs(Parse(body)) do
      entry.members[LocalName(name)] = blessing
    end
  elseif kind == "X" then
    ns.shared[key] = nil
  elseif kind == "Q" then
    if ns.SharesBlessings() then
      Later(1 + (math.random and math.random() or 0.5), true)
    end
    return "Q"
  else
    return nil
  end
  ns.SharedChanged()
  return kind
end

-- What another paladin gives a unit: their choice for that member, else for the member's class (nil: none).
local function TheirChoice(entry, unit)
  local name = GetUnitName(unit, true)
  local key = name and not Secret(name) and entry.members[name]
  if not key then
    local _, class = UnitClass(unit)
    key = class and entry.classes[class]
  end
  if key == nil or key == "none" or not ns.FAMILY[key] then
    return nil
  end
  return key
end

-- The other paladins' blessings for a unit: { [key] = { full Name-Realm, ... } }
function ns.OthersFor(unit)
  local out = {}
  for _, entry in pairs(ns.shared) do
    local key = TheirChoice(entry, unit)
    if key then
      out[key] = out[key] or {}
      table.insert(out[key], entry.full)
    end
  end
  return out
end

-- Whether another paladin takes `key` on this unit. For your chosen blessing (chosen = true) two paladins with
-- the same choice must not both step back: the one whose Name-Realm sorts first keeps it.
function ns.TakenByOther(unit, key, chosen)
  local others = ns.OthersFor(unit)[key]
  if not others then
    return false
  end
  if not chosen then
    return true
  end
  local own = (OwnFull() or ""):lower()
  for _, full in ipairs(others) do
    if full:lower() < own then
      return true
    end
  end
  return false
end

-- Same blessing as another paladin: { { paladin = name, what = class token or member name, member = true|nil,
-- key = blessing key } }, classes first (all classes, also those not in the group), then members of the group.
function ns.ShareConflicts()
  local out = {}
  if not ns.SharesBlessings() then
    return out
  end
  local party = ns.db.party
  local names = {}
  for full in pairs(ns.shared) do
    names[#names + 1] = full
  end
  table.sort(names)
  for _, full in ipairs(names) do
    local entry = ns.shared[full]
    for _, class in ipairs(ns.ShareClasses()) do
      local mine = Effective(party.classes[class] or ns.DEFAULT_BLESSINGS[class])
      if mine ~= "none" and entry.classes[class] == mine then
        out[#out + 1] = { paladin = entry.name, full = full, what = class, key = mine }
      end
    end
    for _, member in ipairs(Members()) do
      local own, theirs = party.members[member.name], entry.members[member.name]
      if own or theirs then -- (class against class is above)
        local mine = Effective(ns.BlessingFor(member.unit))
        if mine ~= "none" and TheirChoice(entry, member.unit) == mine then
          out[#out + 1] = { paladin = entry.name, full = full, what = member.name, member = true, key = mine }
        end
      end
    end
  end
  return out
end

local function ClassName(class)
  return (LOCALIZED_CLASS_NAMES_MALE and LOCALIZED_CLASS_NAMES_MALE[class]) or class
end

local function Label(key)
  local family = ns.FAMILY[key]
  return family and family.label or key
end

-- Chat names each new conflict once: a member's, or a class's when a member of that class gets the class choice from
-- both of you (no own choice on either side); the page shows every class.
local function WarnConflicts()
  local party = ns.db.party
  local members = Members()
  local own = {}
  local _, ownClass = UnitClass("player")
  own.class, own.name = ownClass, GetUnitName("player", true)
  members[#members + 1] = own
  local now = {}
  for _, conflict in ipairs(ns.ShareConflicts()) do
    local id = conflict.paladin .. "\t" .. conflict.what .. "\t" .. conflict.key
    local entry = ns.shared[conflict.full]
    local matters = conflict.member
    if not matters and entry then
      for _, member in ipairs(members) do
        if member.class == conflict.what and member.name and not party.members[member.name]
          and not entry.members[member.name] then
          matters = true
        end
      end
    end
    if warned[id] then
      now[id] = true
    elseif matters then
      now[id] = true
      local what = conflict.member and conflict.what or ClassName(conflict.what)
      print(ns.PREFIX .. L["%s also chose %s for %s. Pick another blessing in the party buff options."]:format(
        conflict.paladin, Label(conflict.key), what))
    end
  end
  warned = now
end

-- Something arrived (or someone left): buttons and the options page follow, chat names new conflicts.
function ns.SharedChanged()
  if ns.PartyDirty then
    ns.PartyDirty()
  end
  WarnConflicts()
end

-- The lines for the Party buffs page ("Other paladins").
function ns.ShareLines()
  local lines = {}
  if not InGroup() then
    lines[1] = L["Join a group: paladins with Buff Tracker or Codex share their blessings here."]
    return lines
  end
  local conflicts = {}
  for _, conflict in ipairs(ns.ShareConflicts()) do
    conflicts[conflict.paladin .. "\t" .. conflict.what] = true
  end
  local names = {}
  for full in pairs(ns.shared) do
    names[#names + 1] = full
  end
  table.sort(names)
  local sharing = {}
  for _, full in ipairs(names) do
    local entry = ns.shared[full]
    sharing[full] = true
    lines[#lines + 1] = "|cfff58cba" .. entry.name .. "|r"
    -- by blessing: "Might: Warrior, Rogue" (red: the same as yours)
    local byKey, order = {}, {}
    for _, class in ipairs(ns.ShareClasses()) do
      local key = entry.classes[class]
      if key and key ~= "none" then
        if not byKey[key] then
          byKey[key] = {}
          order[#order + 1] = key
        end
        local text = ClassName(class)
        if conflicts[entry.name .. "\t" .. class] then
          text = "|cffff4040" .. text .. "|r"
        end
        table.insert(byKey[key], text)
      end
    end
    for _, family in ipairs(ns.BLESSINGS) do
      if byKey[family.key] then
        lines[#lines + 1] = "  " .. L["%s: %s"]:format(family.label, table.concat(byKey[family.key], ", "))
      end
    end
    local members = {}
    for name, key in pairs(entry.members) do
      members[#members + 1] = { name = name, key = key }
    end
    table.sort(members, function(a, b)
      return a.name < b.name
    end)
    for _, member in ipairs(members) do
      local text = member.name
      if conflicts[entry.name .. "\t" .. member.name] then
        text = "|cffff4040" .. text .. "|r"
      end
      lines[#lines + 1] = "  " .. L["%s: %s"]:format(text, member.key == "none" and L["None"] or Label(member.key))
    end
  end
  local silent = {}
  for _, member in ipairs(Members()) do
    if member.class == "PALADIN" and not sharing[member.full:lower()] then
      silent[#silent + 1] = member.name
    end
  end
  if #names == 0 then
    lines[#lines + 1] = L["No other paladin in your group shares blessings."]
  end
  if #silent > 0 then
    lines[#lines + 1] = "|cff909090" .. L["Not sharing (no Buff Tracker or Codex): %s"]:format(table.concat(silent, ", "))
      .. "|r"
  end
  return lines
end

-- Events: Buff Tracker's Events.lua / Codex's Module.lua register these and pass them here.
ns.SHARE_EVENTS = { "CHAT_MSG_ADDON", "GROUP_ROSTER_UPDATE", "PLAYER_ENTERING_WORLD", "PLAYER_REGEN_ENABLED" }

function ns.ShareSetup()
  local register = C_ChatInfo and C_ChatInfo.RegisterAddonMessagePrefix or RegisterAddonMessagePrefix
  if register then
    pcall(register, ns.SHARE_PREFIX)
  end
end

function ns.ShareEvent(event, ...)
  if not ns.db then
    return
  end
  if event == "CHAT_MSG_ADDON" then
    local prefix, text, _, sender = ...
    ns.ShareReceive(prefix, text, sender)
  elseif event == "GROUP_ROSTER_UPDATE" then
    local before = next(ns.shared) ~= nil
    UpdateRoster()
    if before then
      ns.SharedChanged() -- (someone may have left)
    end
  elseif event == "PLAYER_ENTERING_WORLD" then
    wasInGroup = false -- (a reload: ask again)
    UpdateRoster()
  elseif event == "PLAYER_REGEN_ENABLED" then
    if pending then
      pending = false
      Later(1)
    end
  end
end
