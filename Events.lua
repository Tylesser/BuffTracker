local addonName, ns = ...
local L = ns.L

local TICK_SECONDS = 0.2

local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("ADDON_LOADED")
eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
eventFrame:RegisterEvent("SPELLS_CHANGED")
eventFrame:RegisterUnitEvent("UNIT_AURA", "player")
eventFrame:RegisterEvent("BAG_UPDATE_DELAYED")
eventFrame:RegisterEvent("GET_ITEM_INFO_RECEIVED")
eventFrame:RegisterUnitEvent("UNIT_INVENTORY_CHANGED", "player") -- weapon enchants, where nothing else fires
pcall(eventFrame.RegisterEvent, eventFrame, "WEAPON_ENCHANT_CHANGED") -- Retail only
pcall(eventFrame.RegisterEvent, eventFrame, "MINIMAP_UPDATE_TRACKING") -- Find Minerals etc. switched
-- where and when the row shows (Conditions.lua): only a redraw, no rescan (group updates come often in a raid)
local CONDITION_EVENTS = { ZONE_CHANGED_NEW_AREA = true, PLAYER_UPDATE_RESTING = true, GROUP_ROSTER_UPDATE = true,
  ACTIVE_TALENT_GROUP_CHANGED = true, PLAYER_TALENT_UPDATE = true, -- (talents: also once known after a login)
  PLAYER_ROLES_ASSIGNED = true }
for event in pairs(CONDITION_EVENTS) do
  pcall(eventFrame.RegisterEvent, eventFrame, event) -- (the talent event: not in every game)
end

local function Setup()
  BuffTrackerDB = BuffTrackerDB or {}
  for key, value in pairs(ns.defaults) do
    if BuffTrackerDB[key] == nil then
      BuffTrackerDB[key] = value
    end
  end
  BuffTrackerDB.tracked = BuffTrackerDB.tracked or {}
  ns.db = BuffTrackerDB
  ns.SetupParty()
  ns.SetupDispel()
  ns.CreateDisplay()
  ns.ShareSetup() -- blessings shared with the other paladins (Share.lua)
  ns.ApplyNextKey() -- the next missing buff key (NextBuff.lua)
  ns.CreateOptions()
  ns.CreatePartyOptions()
  ns.CreateDispelOptions()
  ns.T.AddCompartment({ text = ns.TITLE, onClick = ns.OpenOptions, tooltip = { L["Click to open the options."] } })
end

eventFrame:SetScript("OnEvent", function(self, event, loadedName)
  if event == "ADDON_LOADED" then
    if loadedName == addonName then
      Setup()
      self:UnregisterEvent("ADDON_LOADED")
    end
    return
  end
  if not ns.db then
    return
  end
  if CONDITION_EVENTS[event] then
    ns.UpdateDisplay()
    ns.RefreshConditions()
    return
  end
  if event == "GET_ITEM_INFO_RECEIVED" then
    if not ns.ItemPending(loadedName) then -- loadedName is the item ID here
      return
    end
    ns.ScanBags()
  elseif event == "BAG_UPDATE_DELAYED" then
    ns.ScanBags()
  elseif event == "SPELLS_CHANGED" then
    ns.RefreshKnown() -- before the click overlays are laid out again: they depend on known spells
  end
  if event == "PLAYER_ENTERING_WORLD" and #ns.db.tracked == 0 and not ns.db.welcomed then
    ns.db.welcomed = true
    print(ns.PREFIX .. L["type %s to choose the buffs to track."]:format("/btrack"))
  end
  ns.Changed()
end)

-- Blessings shared with the other paladins (Share.lua), and the next buff key after a fight (NextBuff.lua).
local shareFrame = CreateFrame("Frame")
for _, event in ipairs(ns.SHARE_EVENTS) do
  pcall(shareFrame.RegisterEvent, shareFrame, event)
end
shareFrame:SetScript("OnEvent", function(_, event, ...)
  if not ns.db then
    return
  end
  if event == "PLAYER_REGEN_ENABLED" and ns.NextKeyPending() then
    ns.ApplyNextKey()
  end
  ns.ShareEvent(event, ...)
end)

local sinceTick = 0
eventFrame:SetScript("OnUpdate", function(_, elapsed)
  sinceTick = sinceTick + elapsed
  if sinceTick >= TICK_SECONDS and ns.db then
    ns.Tick(sinceTick)
    ns.PartyTick(sinceTick)
    sinceTick = 0
  end
end)

local function PrintList()
  if #ns.db.tracked == 0 then
    print(ns.PREFIX .. L["nothing tracked yet."])
    return
  end
  print(ns.PREFIX .. L["tracked buffs:"])
  for _, entry in ipairs(ns.db.tracked) do
    local state = ns.StateOf(entry)
    local current = "|cffaaaaaa" .. L["unknown"] .. "|r"
    if state and state.active then
      current = "|cff20ff20" .. L["on"] .. "|r"
    elseif state and state.known then
      current = "|cffff4040" .. L["missing"] .. "|r"
    end
    print("  " .. L["%s: %s (show: %s)"]:format(ns.EntryName(entry), current, ns.MODE_LABELS[entry.mode]))
  end
  if not ns.scanComplete then
    print("  " .. L["The game is hiding your buffs right now, so these may be out of date."])
  end
end

SLASH_BUFFTRACKER1 = "/btrack"
SLASH_BUFFTRACKER2 = "/bufftracker"
SlashCmdList.BUFFTRACKER = function(msg)
  msg = strtrim(msg or "")
  local command, rest = msg:match("^(%S+)%s*(.*)$")
  command = command and command:lower() or ""

  if command == "" then
    ns.OpenOptions()
  elseif command == "add" then
    local entry, reason = ns.AddBuff(rest)
    if entry then
      print(ns.PREFIX .. L["now tracking %s."]:format(ns.EntryName(entry)))
    else
      print(ns.PREFIX .. reason)
    end
  elseif command == "remove" then
    if ns.RemoveBuff(rest) then
      print(ns.PREFIX .. L["stopped tracking %s."]:format(rest))
    else
      print(ns.PREFIX .. L["%s is not tracked."]:format(rest))
    end
  elseif command == "basics" then
    ns.AddPreset()
  elseif command == "item" then
    -- /btrack item <buff> = <item name, ID or link>; without "= item" it goes back to none
    local name, item = rest:match("^(.-)%s*=%s*(.-)$")
    name = strtrim(name or rest)
    local entry = ns.FindTracked(name)
    if not entry then
      print(ns.PREFIX .. L["%s is not tracked."]:format(name ~= "" and name or L["that buff"]))
    elseif not item or item == "" then
      ns.SetItem(entry, nil)
      print(ns.PREFIX .. L["%s no longer uses an item."]:format(ns.EntryName(entry)))
    else
      local id = ns.ResolveItem(item)
      if id and ns.IsEquippable(id) then
        print(ns.PREFIX .. L["that item is worn, not used: clicking it would equip it."])
      elseif id then
        ns.SetItem(entry, id)
        print(ns.PREFIX .. L["clicking %s now uses %s."]:format(ns.EntryName(entry), ns.ItemName(id) or L["item %s"]:format(id)))
      else
        print(ns.PREFIX .. L["no item called %s found. Try its item ID, or shift-click it into the line."]:format(item))
      end
    end
  elseif command == "party" then
    ns.OpenPartyOptions()
  elseif command == "dispel" or command == "dispels" then
    ns.OpenDispelOptions()
  elseif command == "debug" then
    ns.PartyDebug()
    print(ns.PREFIX .. "tracking: " .. ns.TrackingDebug())
  elseif command == "feedback" then
    ns.T.ShowFeedback()
  elseif command == "list" then
    PrintList()
  elseif command == "lock" or command == "unlock" then
    ns.SetLocked(command == "lock")
  elseif command == "reset" then
    ns.ResetPosition()
  else
    print(ns.PREFIX .. L["commands:"])
    print("  " .. L["%s: open the options, %s: party buff buttons and blessings"]:format("/btrack", "/btrack party"))
    print("  /btrack dispel: " .. L["dispel buttons for your party and yourself"])
    print("  " .. L["%s <name or spell ID>, %s <name>, %s"]:format("/btrack add", "/btrack remove", "/btrack list"))
    print("  /btrack basics: " .. L["track the basic buffs of your class"])
    print("  " .. L["%s <buff> = <item>: the item a click on that icon uses"]:format("/btrack item"))
    print("  /btrack lock, /btrack unlock, /btrack reset (" .. L["put the icons back in place"] .. ")")
    print("  /btrack debug: " .. L["show what the party buttons see"])
    print("  /btrack feedback: " .. L["report a bug or suggest an idea"])

  end
end
